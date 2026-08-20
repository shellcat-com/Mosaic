create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create type public.member_role as enum ('participant', 'organizer');
create type public.privacy_mode as enum ('first_name', 'anonymous', 'quiet');
create type public.challenge_status as enum ('active', 'revealed', 'archived');
create type public.evidence_method as enum ('reflection', 'photo', 'video', 'receipt', 'partner', 'organizer');
create type public.emotion as enum ('hopeful', 'joyful', 'caring', 'calm');
create type public.contribution_status as enum ('draft', 'pending_review', 'self_attested', 'verified', 'rejected', 'placed', 'revealed', 'archived');
create type public.review_status as enum ('pending', 'approved', 'rejected');

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  is_demo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (char_length(display_name) <= 60)
);

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid references auth.users(id) on delete cascade,
  name text not null,
  purpose text not null,
  goal integer not null,
  reveal_at timestamptz not null,
  status public.challenge_status not null default 'active',
  invitation_code text not null unique,
  is_showcase boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint challenges_name_length check (char_length(name) between 1 and 100),
  constraint challenges_purpose_length check (char_length(purpose) between 1 and 500),
  constraint challenges_goal_range check (goal between 1 and 10000),
  constraint challenges_invitation_code_format check (invitation_code ~ '^[A-Z0-9]{6,12}$'),
  constraint showcase_has_no_organizer check (not is_showcase or organizer_id is null)
);

create unique index one_sandbox_per_organizer
  on public.challenges(organizer_id)
  where organizer_id is not null and is_showcase = false;

create table public.challenge_members (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.member_role not null default 'participant',
  display_name text not null default '',
  privacy public.privacy_mode not null default 'first_name',
  joined_at timestamptz not null default now(),
  primary key (challenge_id, user_id),
  constraint challenge_members_display_name_length check (char_length(display_name) <= 60)
);

create index challenge_members_user_idx on public.challenge_members(user_id, challenge_id);

create table public.missions (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  title text not null,
  detail text not null,
  category text not null,
  minutes integer not null,
  effort text not null,
  accepted_evidence public.evidence_method[] not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint missions_minutes_range check (minutes between 1 and 1440),
  constraint missions_category check (category in ('encouragement', 'giving', 'community', 'teaching', 'support', 'connection')),
  constraint missions_no_partner_for_hackathon check (not ('partner' = any(accepted_evidence)))
);

create index missions_challenge_idx on public.missions(challenge_id, sort_order);

create table public.contributions (
  id uuid primary key,
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete restrict,
  emotion public.emotion not null,
  evidence_method public.evidence_method not null,
  status public.contribution_status not null default 'draft',
  verification_level text,
  tile_position integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint contributions_verification_level check (verification_level is null or verification_level in ('self_attested', 'organizer_verified')),
  constraint contributions_tile_position_positive check (tile_position is null or tile_position >= 0),
  unique (challenge_id, tile_position)
);

create index contributions_challenge_idx on public.contributions(challenge_id, created_at);

create table public.contribution_owners (
  contribution_id uuid primary key references public.contributions(id) on delete cascade,
  participant_id uuid not null references auth.users(id) on delete cascade,
  include_memory boolean not null default false,
  show_identity boolean not null default false,
  export_consent boolean not null default false,
  created_at timestamptz not null default now()
);

create index contribution_owners_participant_idx on public.contribution_owners(participant_id);

create table public.evidence_submissions (
  contribution_id uuid primary key references public.contributions(id) on delete cascade,
  reflection_text text,
  media_path text,
  mime_type text,
  file_size bigint,
  duration_seconds numeric(5,2),
  review_status public.review_status not null default 'pending',
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint evidence_text_length check (reflection_text is null or char_length(reflection_text) <= 2000),
  constraint evidence_file_size check (file_size is null or file_size between 1 and 26214400),
  constraint evidence_video_duration check (duration_seconds is null or duration_seconds between 0 and 10.0)
);

create table public.memories (
  id uuid primary key default gen_random_uuid(),
  contribution_id uuid not null unique references public.contributions(id) on delete cascade,
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  story_text text,
  media_path text,
  show_identity boolean not null default false,
  export_consent boolean not null default false,
  review_status public.review_status not null default 'pending',
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  constraint memories_story_length check (story_text is null or char_length(story_text) <= 2000)
);

create index memories_challenge_idx on public.memories(challenge_id, review_status);

create table public.moderation_actions (
  id bigint generated always as identity primary key,
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  contribution_id uuid not null references public.contributions(id) on delete cascade,
  moderator_id uuid not null references auth.users(id) on delete restrict,
  decision public.review_status not null,
  note text,
  created_at timestamptz not null default now(),
  constraint moderation_note_length check (note is null or char_length(note) <= 500),
  constraint moderation_actions_idempotent unique (contribution_id, decision)
);

create index moderation_actions_challenge_idx on public.moderation_actions(challenge_id, created_at desc);

create function private.is_challenge_member(requested_challenge_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.challenge_members cm
    where cm.challenge_id = requested_challenge_id
      and cm.user_id = (select auth.uid())
  );
$$;

create function private.is_challenge_organizer(requested_challenge_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.challenge_members cm
    where cm.challenge_id = requested_challenge_id
      and cm.user_id = (select auth.uid())
      and cm.role = 'organizer'
  );
$$;

create function private.owns_contribution(requested_contribution_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.contribution_owners co
    where co.contribution_id = requested_contribution_id
      and co.participant_id = (select auth.uid())
  );
$$;

revoke all on function private.is_challenge_member(uuid) from public, anon;
revoke all on function private.is_challenge_organizer(uuid) from public, anon;
revoke all on function private.owns_contribution(uuid) from public, anon;
grant execute on function private.is_challenge_member(uuid) to authenticated, service_role;
grant execute on function private.is_challenge_organizer(uuid) to authenticated, service_role;
grant execute on function private.owns_contribution(uuid) to authenticated, service_role;

alter table public.profiles enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_members enable row level security;
alter table public.missions enable row level security;
alter table public.contributions enable row level security;
alter table public.contribution_owners enable row level security;
alter table public.evidence_submissions enable row level security;
alter table public.memories enable row level security;
alter table public.moderation_actions enable row level security;

create policy "profiles are private"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "members can read challenges"
  on public.challenges for select to authenticated
  using (private.is_challenge_member(id));

create policy "members read themselves and organizers read roster"
  on public.challenge_members for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.is_challenge_organizer(challenge_id)
  );

create policy "members can read missions"
  on public.missions for select to authenticated
  using (private.is_challenge_member(challenge_id));

create policy "members can read safe contribution tiles"
  on public.contributions for select to authenticated
  using (private.is_challenge_member(challenge_id));

create policy "owners and organizers can read contribution ownership"
  on public.contribution_owners for select to authenticated
  using (
    participant_id = (select auth.uid())
    or exists (
      select 1 from public.contributions c
      where c.id = contribution_id
        and private.is_challenge_organizer(c.challenge_id)
    )
  );

create policy "owners and organizers can read evidence"
  on public.evidence_submissions for select to authenticated
  using (
    private.owns_contribution(contribution_id)
    or exists (
      select 1 from public.contributions c
      where c.id = contribution_id
        and private.is_challenge_organizer(c.challenge_id)
    )
  );

create policy "approved memories appear only after reveal"
  on public.memories for select to authenticated
  using (
    private.owns_contribution(contribution_id)
    or private.is_challenge_organizer(challenge_id)
    or (
      review_status = 'approved'
      and private.is_challenge_member(challenge_id)
      and exists (
        select 1 from public.challenges c
        where c.id = challenge_id and c.status = 'revealed'
      )
    )
  );

create policy "organizers can read moderation audit"
  on public.moderation_actions for select to authenticated
  using (private.is_challenge_organizer(challenge_id));

revoke all on table public.profiles, public.challenges, public.challenge_members,
  public.missions, public.contributions, public.contribution_owners,
  public.evidence_submissions, public.memories, public.moderation_actions
  from anon, authenticated;

grant select on table public.profiles, public.challenges, public.challenge_members,
  public.missions, public.contributions, public.contribution_owners,
  public.evidence_submissions, public.memories, public.moderation_actions
  to authenticated;

grant all on table public.profiles, public.challenges, public.challenge_members,
  public.missions, public.contributions, public.contribution_owners,
  public.evidence_submissions, public.memories, public.moderation_actions
  to service_role;
grant usage, select on sequence public.moderation_actions_id_seq to service_role;

create function public.internal_place_tile(target_contribution_id uuid, target_user_id uuid)
returns public.contributions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.contributions;
  next_position integer;
begin
  select c.* into target
  from public.contributions c
  join public.contribution_owners co on co.contribution_id = c.id
  where c.id = target_contribution_id and co.participant_id = target_user_id;

  if not found then raise exception 'contribution not owned by caller'; end if;
  if target.status = 'placed' then return target; end if;
  if target.status not in ('self_attested', 'verified') then
    raise exception 'contribution is not ready for placement';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(target.challenge_id::text, 0));
  select coalesce(max(c.tile_position), -1) + 1 into next_position
  from public.contributions c where c.challenge_id = target.challenge_id;

  update public.contributions
  set status = 'placed', tile_position = next_position, updated_at = now()
  where id = target_contribution_id
  returning * into target;
  return target;
end;
$$;

revoke all on function public.internal_place_tile(uuid, uuid) from public, anon, authenticated;
grant execute on function public.internal_place_tile(uuid, uuid) to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('evidence-private', 'evidence-private', false, 26214400, array['image/jpeg', 'image/png', 'video/quicktime', 'video/mp4']),
  ('memory-private', 'memory-private', false, 26214400, array['image/jpeg', 'image/png', 'video/quicktime', 'video/mp4'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create function private.broadcast_mosaic_invalidation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_challenge_id uuid;
  target_record_id uuid;
begin
  if tg_table_name = 'challenges' then
    target_challenge_id := coalesce(new.id, old.id);
    target_record_id := target_challenge_id;
  else
    target_challenge_id := coalesce(new.challenge_id, old.challenge_id);
    target_record_id := coalesce(new.id, old.id);
  end if;

  perform realtime.send(
    jsonb_build_object(
      'entity', tg_table_name,
      'record_id', target_record_id,
      'operation', tg_op
    ),
    'changed',
    'challenge:' || target_challenge_id::text,
    true
  );
  return coalesce(new, old);
end;
$$;

revoke all on function private.broadcast_mosaic_invalidation() from public, anon, authenticated;

create trigger challenges_broadcast_invalidation
after insert or update or delete on public.challenges
for each row execute function private.broadcast_mosaic_invalidation();

create trigger contributions_broadcast_invalidation
after insert or update or delete on public.contributions
for each row execute function private.broadcast_mosaic_invalidation();

create trigger memories_broadcast_invalidation
after insert or update or delete on public.memories
for each row execute function private.broadcast_mosaic_invalidation();

create policy "challenge members receive private broadcasts"
on realtime.messages for select to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and exists (
    select 1
    from public.challenge_members cm
    where cm.user_id = (select auth.uid())
      and ('challenge:' || cm.challenge_id::text) = (select realtime.topic())
  )
);

create function private.activate_due_reveals()
returns void
language sql
security definer
set search_path = ''
as $$
  with due as (
    update public.challenges
    set status = 'revealed', updated_at = now()
    where status = 'active' and reveal_at <= now()
    returning id
  )
  update public.contributions contribution
  set status = 'revealed', updated_at = now()
  where contribution.status = 'placed'
    and contribution.challenge_id in (select id from due);
$$;

revoke all on function private.activate_due_reveals() from public, anon, authenticated;

select cron.schedule(
  'mosaic-activate-due-reveals',
  '* * * * *',
  'select private.activate_due_reveals()'
);
