alter table public.challenges
  add column revealed_at timestamptz,
  add column schedule_revision integer not null default 1,
  add column featured_recap_export_id uuid;

alter table public.challenges
  add constraint challenges_schedule_revision_positive check (schedule_revision > 0),
  add constraint challenges_featured_recap_fk
    foreign key (featured_recap_export_id)
    references public.recap_exports(id)
    on delete set null;

alter table public.recap_exports
  add column thumbnail_path text,
  add constraint recap_exports_thumbnail_path_safe check (
    thumbnail_path is null
    or (char_length(thumbnail_path) between 1 and 500 and thumbnail_path !~ '(^|/)\.\.(/|$)')
  );

create table public.event_notification_preferences (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  challenge_start boolean not null default true,
  reveal_day_before boolean not null default true,
  reveal_hour_before boolean not null default true,
  reveal_now boolean not null default true,
  recap_ready boolean not null default true,
  schedule_changes boolean not null default true,
  live_activity boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (challenge_id, user_id)
);

create index event_notification_preferences_user_idx
  on public.event_notification_preferences(user_id, challenge_id);

create table public.notification_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  environment text not null,
  last_seen_at timestamptz not null default now(),
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  constraint notification_devices_environment check (environment in ('sandbox', 'production')),
  constraint notification_devices_token_format check (
    char_length(token) between 64 and 256 and token ~ '^[a-f0-9]+$'
  )
);

create index notification_devices_user_active_idx
  on public.notification_devices(user_id)
  where disabled_at is null;

create table public.live_activity_tokens (
  user_id uuid not null references auth.users(id) on delete cascade,
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  activity_id text not null,
  token text not null unique,
  environment text not null default 'sandbox',
  last_seen_at timestamptz not null default now(),
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (user_id, activity_id),
  constraint live_activity_tokens_activity_id_length check (char_length(activity_id) between 1 and 200),
  constraint live_activity_tokens_environment check (environment in ('sandbox', 'production')),
  constraint live_activity_tokens_token_format check (
    char_length(token) between 64 and 256 and token ~ '^[a-f0-9]+$'
  )
);

create index live_activity_tokens_challenge_active_idx
  on public.live_activity_tokens(challenge_id, user_id)
  where disabled_at is null;

create table public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  schedule_revision integer not null,
  dedupe_key text not null unique,
  status text not null default 'pending',
  provider_id text,
  error text,
  created_at timestamptz not null default now(),
  attempted_at timestamptz,
  delivered_at timestamptz,
  constraint notification_deliveries_kind check (
    kind in ('schedule_changed', 'early_reveal', 'recap_ready', 'live_activity')
  ),
  constraint notification_deliveries_status check (
    status in ('pending', 'sending', 'sent', 'failed', 'skipped')
  ),
  constraint notification_deliveries_schedule_revision_positive check (schedule_revision > 0),
  constraint notification_deliveries_error_length check (error is null or char_length(error) <= 1000)
);

create index notification_deliveries_pending_idx
  on public.notification_deliveries(created_at)
  where status = 'pending';

alter table public.event_notification_preferences enable row level security;
alter table public.notification_devices enable row level security;
alter table public.live_activity_tokens enable row level security;
alter table public.notification_deliveries enable row level security;

create policy "members manage own event preferences"
  on public.event_notification_preferences for select to authenticated
  using (
    user_id = (select auth.uid())
    and private.is_challenge_member(challenge_id)
  );

create policy "members create own event preferences"
  on public.event_notification_preferences for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and private.is_challenge_member(challenge_id)
  );

create policy "members update own event preferences"
  on public.event_notification_preferences for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and private.is_challenge_member(challenge_id)
  );

create policy "members delete own event preferences"
  on public.event_notification_preferences for delete to authenticated
  using (user_id = (select auth.uid()));

revoke all on table public.event_notification_preferences,
  public.notification_devices,
  public.live_activity_tokens,
  public.notification_deliveries
from anon, authenticated;

grant select, insert, update, delete on table public.event_notification_preferences to authenticated;
grant all on table public.event_notification_preferences,
  public.notification_devices,
  public.live_activity_tokens,
  public.notification_deliveries
to service_role;

create function private.increment_challenge_schedule_revision()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.reveal_at is distinct from old.reveal_at then
    new.schedule_revision := old.schedule_revision + 1;
  end if;
  return new;
end;
$$;

revoke all on function private.increment_challenge_schedule_revision() from public, anon, authenticated;

create trigger challenges_increment_schedule_revision
before update of reveal_at on public.challenges
for each row execute function private.increment_challenge_schedule_revision();

create function private.enqueue_challenge_event_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.reveal_at is distinct from old.reveal_at then
    insert into public.notification_deliveries (
      challenge_id, user_id, kind, schedule_revision, dedupe_key
    )
    select
      new.id,
      preference.user_id,
      'schedule_changed',
      new.schedule_revision,
      'schedule:' || new.id::text || ':' || new.schedule_revision::text || ':' || preference.user_id::text
    from public.event_notification_preferences preference
    where preference.challenge_id = new.id and preference.schedule_changes
    on conflict (dedupe_key) do nothing;
  end if;

  if old.status = 'active'
     and new.status = 'revealed'
     and old.reveal_at > now() + interval '1 minute' then
    insert into public.notification_deliveries (
      challenge_id, user_id, kind, schedule_revision, dedupe_key
    )
    select
      new.id,
      preference.user_id,
      'early_reveal',
      new.schedule_revision,
      'early-reveal:' || new.id::text || ':' || new.schedule_revision::text || ':' || preference.user_id::text
    from public.event_notification_preferences preference
    where preference.challenge_id = new.id and preference.reveal_now
    on conflict (dedupe_key) do nothing;
  end if;
  return new;
end;
$$;

revoke all on function private.enqueue_challenge_event_notifications() from public, anon, authenticated;

create trigger challenges_enqueue_event_notifications
after update of reveal_at, status on public.challenges
for each row execute function private.enqueue_challenge_event_notifications();

create function private.feature_completed_recap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_revision integer;
  selected_recap_id uuid;
begin
  if new.visibility = 'challenge'
     and new.status = 'completed_uploaded'
     and (old.status is distinct from new.status or old.visibility is distinct from new.visibility) then
    select recap.id into selected_recap_id
    from public.recap_exports recap
    where recap.challenge_id = new.challenge_id
      and recap.visibility = 'challenge'
      and recap.status = 'completed_uploaded'
    order by recap.created_at, recap.id
    limit 1;

    update public.challenges
    set featured_recap_export_id = selected_recap_id,
        updated_at = now()
    where id = new.challenge_id
    returning schedule_revision into target_revision;

    if exists (
      select 1 from public.challenges
      where id = new.challenge_id and featured_recap_export_id = selected_recap_id
    ) then
      insert into public.notification_deliveries (
        challenge_id, user_id, kind, schedule_revision, dedupe_key
      )
      select
        new.challenge_id,
        preference.user_id,
        'recap_ready',
        target_revision,
        'recap:' || new.challenge_id::text || ':' || preference.user_id::text
      from public.event_notification_preferences preference
      where preference.challenge_id = new.challenge_id and preference.recap_ready
      on conflict (dedupe_key) do nothing;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.feature_completed_recap() from public, anon, authenticated;

create trigger recap_exports_feature_completed
after update of status, visibility on public.recap_exports
for each row execute function private.feature_completed_recap();

create or replace function private.activate_due_reveals()
returns void
language sql
security definer
set search_path = ''
as $$
  with due as (
    update public.challenges
    set status = 'revealed', revealed_at = coalesce(revealed_at, now()), updated_at = now()
    where status = 'active' and reveal_at <= now()
    returning id
  )
  update public.contributions contribution
  set status = 'revealed', updated_at = now()
  where contribution.status = 'placed'
    and contribution.challenge_id in (select id from due);
$$;

revoke all on function private.activate_due_reveals() from public, anon, authenticated;

create function private.enqueue_due_live_activities()
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notification_deliveries (
    challenge_id, user_id, kind, schedule_revision, dedupe_key
  )
  select
    challenge.id,
    preference.user_id,
    'live_activity',
    challenge.schedule_revision,
    'live:' || challenge.id::text || ':' || challenge.schedule_revision::text || ':' || preference.user_id::text
  from public.challenges challenge
  join public.event_notification_preferences preference
    on preference.challenge_id = challenge.id
  where challenge.status = 'active'
    and preference.live_activity
    and challenge.reveal_at > now()
    and challenge.reveal_at <= now() + interval '30 minutes'
  on conflict (dedupe_key) do nothing;
$$;

revoke all on function private.enqueue_due_live_activities() from public, anon, authenticated;

select cron.schedule(
  'mosaic-live-activity-enqueue',
  '* * * * *',
  'select private.enqueue_due_live_activities()'
);

-- A published widget card is a separate, privacy-reviewed derivative. Storage
-- access remains tied to the export row so arbitrary files under the user's
-- folder cannot be uploaded or read through this bucket.
drop policy if exists "creators upload recap exports" on storage.objects;
create policy "creators upload recap exports"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'recap-exports'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1 from public.recap_exports re
    where re.creator_id = (select auth.uid())
      and (re.storage_path = name or re.thumbnail_path = name)
  )
);

drop policy if exists "authorized users read recap exports" on storage.objects;
create policy "authorized users read recap exports"
on storage.objects for select to authenticated
using (
  bucket_id = 'recap-exports'
  and exists (
    select 1 from public.recap_exports re
    where (re.storage_path = name or re.thumbnail_path = name)
      and (
        re.creator_id = (select auth.uid())
        or (re.visibility = 'challenge' and private.is_challenge_member(re.challenge_id))
      )
  )
);
