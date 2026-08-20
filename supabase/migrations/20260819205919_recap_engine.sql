alter table public.challenges
  add column group_name text not null default 'Mosaic Community',
  add column start_at timestamptz not null default now(),
  add column mosaic_version integer not null default 1,
  add column impact_receipt_version integer not null default 1;

alter table public.memories
  add column media_version integer not null default 1,
  add column consent_version integer not null default 1,
  add column deleted_at timestamptz,
  add column reported_at timestamptz;

create type public.recap_export_status as enum (
  'queued', 'rendering', 'muxing', 'completed_local', 'completed_uploaded', 'failed', 'cancelled'
);
create type public.recap_export_visibility as enum ('creator', 'challenge');

create table public.impact_receipts (
  challenge_id uuid primary key references public.challenges(id) on delete cascade,
  version integer not null default 1,
  accepted_actions integer not null default 0,
  participant_count integer not null default 0,
  mission_totals jsonb not null default '{}'::jsonb,
  pass_the_tile_joins integer not null default 0,
  organizer_units jsonb not null default '[]'::jsonb,
  verified_at timestamptz not null default now(),
  constraint impact_receipts_nonnegative check (
    accepted_actions >= 0 and participant_count >= 0 and pass_the_tile_joins >= 0 and version > 0
  )
);

create table public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_id)
);

create table public.memory_reports (
  memory_id uuid not null references public.memories(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  primary key (memory_id, reporter_id),
  constraint memory_reports_reason_length check (char_length(reason) between 1 and 500)
);

create table public.recap_exports (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  creator_id uuid not null references auth.users(id) on delete cascade,
  fingerprint text not null,
  preset_id text not null,
  music_id text,
  music_trim_offset numeric(10,3) not null default 0,
  options jsonb not null default '{}'::jsonb,
  status public.recap_export_status not null default 'queued',
  progress numeric(5,4) not null default 0,
  visibility public.recap_export_visibility not null default 'creator',
  storage_path text,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint recap_exports_creator_fingerprint unique (creator_id, fingerprint),
  constraint recap_exports_fingerprint_format check (fingerprint ~ '^[a-f0-9]{64}$'),
  constraint recap_exports_progress_range check (progress between 0 and 1),
  constraint recap_exports_trim_nonnegative check (music_trim_offset >= 0)
);

create index recap_exports_challenge_idx on public.recap_exports(challenge_id, updated_at desc);

create function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger recap_exports_touch_updated_at
before update on public.recap_exports
for each row execute function private.touch_updated_at();

create function private.flag_reported_memory()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.memories set reported_at = coalesce(reported_at, now()) where id = new.memory_id;
  return new;
end;
$$;

create trigger memory_reports_flag_memory
after insert on public.memory_reports
for each row execute function private.flag_reported_memory();

alter table public.impact_receipts enable row level security;
alter table public.user_blocks enable row level security;
alter table public.memory_reports enable row level security;
alter table public.recap_exports enable row level security;

create policy "revealed members read impact receipts"
  on public.impact_receipts for select to authenticated
  using (
    private.is_challenge_member(challenge_id)
    and exists (select 1 from public.challenges c where c.id = challenge_id and c.status = 'revealed')
  );

create policy "users manage their own block list"
  on public.user_blocks for select to authenticated
  using (blocker_id = (select auth.uid()));
create policy "users add their own blocks"
  on public.user_blocks for insert to authenticated
  with check (blocker_id = (select auth.uid()));
create policy "users remove their own blocks"
  on public.user_blocks for delete to authenticated
  using (blocker_id = (select auth.uid()));

create policy "members report visible memories"
  on public.memory_reports for insert to authenticated
  with check (
    reporter_id = (select auth.uid())
    and exists (
      select 1 from public.memories m
      where m.id = memory_id and private.is_challenge_member(m.challenge_id)
    )
  );
create policy "reporters and organizers read reports"
  on public.memory_reports for select to authenticated
  using (
    reporter_id = (select auth.uid())
    or exists (
      select 1 from public.memories m
      where m.id = memory_id and private.is_challenge_organizer(m.challenge_id)
    )
  );

create policy "creators read own recap exports"
  on public.recap_exports for select to authenticated
  using (
    creator_id = (select auth.uid())
    or (visibility = 'challenge' and status = 'completed_uploaded' and private.is_challenge_member(challenge_id))
  );
create policy "members create own recap exports"
  on public.recap_exports for insert to authenticated
  with check (creator_id = (select auth.uid()) and private.is_challenge_member(challenge_id));
create policy "creators update own recap exports"
  on public.recap_exports for update to authenticated
  using (creator_id = (select auth.uid()))
  with check (creator_id = (select auth.uid()) and private.is_challenge_member(challenge_id));

create policy "revealed approved contributors may be attributed"
  on public.challenge_members for select to authenticated
  using (
    private.is_challenge_member(challenge_id)
    and exists (
      select 1
      from public.contribution_owners co
      join public.contributions c on c.id = co.contribution_id
      join public.memories m on m.contribution_id = c.id
      join public.challenges challenge on challenge.id = c.challenge_id
      where co.participant_id = challenge_members.user_id
        and c.challenge_id = challenge_members.challenge_id
        and m.show_identity
        and m.export_consent
        and m.review_status = 'approved'
        and challenge.status = 'revealed'
    )
  );

create policy "revealed members read consented memory ownership"
  on public.contribution_owners for select to authenticated
  using (
    private.is_challenge_member((select c.challenge_id from public.contributions c where c.id = contribution_id))
    and exists (
      select 1
      from public.contributions c
      join public.memories m on m.contribution_id = c.id
      join public.challenges challenge on challenge.id = c.challenge_id
      where c.id = contribution_id
        and m.review_status = 'approved'
        and m.export_consent
        and m.deleted_at is null
        and m.reported_at is null
        and challenge.status = 'revealed'
    )
  );

create view public.recap_sources with (security_invoker = true) as
select
  m.id,
  m.contribution_id,
  c.challenge_id,
  co.participant_id,
  case when m.show_identity then nullif(cm.display_name, '') else null end as participant_display_name,
  m.show_identity as attribution_allowed,
  mission.category,
  coalesce(m.approved_at, c.updated_at) as accepted_at,
  m.media_path,
  m.story_text,
  c.emotion::text as emotion,
  c.tile_position,
  false as is_revived,
  m.media_version,
  m.consent_version,
  (c.status in ('verified', 'placed', 'revealed')) as accepted,
  m.export_consent as recap_consent,
  (m.media_path is not null or m.story_text is not null) as media_exists,
  (m.deleted_at is not null) as is_deleted,
  (m.reported_at is not null) as is_reported,
  exists (
    select 1 from public.user_blocks ub
    where ub.blocker_id = (select auth.uid()) and ub.blocked_id = co.participant_id
  ) as contributor_is_blocked
from public.memories m
join public.contributions c on c.id = m.contribution_id
join public.contribution_owners co on co.contribution_id = c.id
join public.missions mission on mission.id = c.mission_id
left join public.challenge_members cm on cm.challenge_id = c.challenge_id and cm.user_id = co.participant_id
join public.challenges challenge on challenge.id = c.challenge_id
where challenge.status = 'revealed'
  and m.review_status = 'approved'
  and m.export_consent
  and m.deleted_at is null
  and m.reported_at is null
  and not exists (
    select 1 from public.user_blocks ub
    where ub.blocker_id = (select auth.uid()) and ub.blocked_id = co.participant_id
  );

revoke all on table public.impact_receipts, public.user_blocks, public.memory_reports, public.recap_exports from anon, authenticated;
grant select on table public.impact_receipts to authenticated;
grant select, insert, delete on table public.user_blocks to authenticated;
grant select, insert on table public.memory_reports to authenticated;
grant select, insert, update on table public.recap_exports to authenticated;
grant select on table public.recap_sources to authenticated;
grant all on table public.impact_receipts, public.user_blocks, public.memory_reports, public.recap_exports to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('recap-memories', 'recap-memories', false, 26214400, array['image/jpeg', 'image/png']),
  ('recap-exports', 'recap-exports', false, 157286400, array['video/mp4', 'image/jpeg', 'image/png'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "creators upload recap exports"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'recap-exports'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1 from public.recap_exports re
    where re.creator_id = (select auth.uid()) and re.storage_path = name
  )
);

create policy "authorized users read recap exports"
on storage.objects for select to authenticated
using (
  bucket_id = 'recap-exports'
  and exists (
    select 1 from public.recap_exports re
    where re.storage_path = name
      and (re.creator_id = (select auth.uid()) or (re.visibility = 'challenge' and private.is_challenge_member(re.challenge_id)))
  )
);

alter publication supabase_realtime add table public.recap_exports;
