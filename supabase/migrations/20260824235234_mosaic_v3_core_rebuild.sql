-- Additive Mosaic V3 backend.
-- V3 product tables are namespaced so this migration can be applied to the
-- populated legacy project without dropping schemas, accounts, or legacy data.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_cron;

create table if not exists public.mosaic_v3_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 2 and 40),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mosaic_v3_artwork_catalog (
  id uuid primary key,
  title text not null,
  artist text not null,
  asset_name text not null unique,
  source_url text not null,
  license text not null,
  alt_text text not null,
  reviewed_at timestamptz not null,
  enabled boolean not null default true
);

create table public.mosaic_v3_mosaics (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.mosaic_v3_profiles(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  community_name text not null check (char_length(btrim(community_name)) between 1 and 80),
  description text not null default '' check (char_length(description) <= 600),
  invitation_code text not null unique check (invitation_code ~ '^[A-Z0-9]{8}$'),
  artwork_id uuid not null references public.mosaic_v3_artwork_catalog(id),
  film_look_id text not null check (film_look_id in ('sunwashed', 'garden', 'afterglow')),
  shot_limit integer not null check (shot_limit in (12, 24, 36)),
  tile_goal integer not null check (tile_goal in (9, 16, 25, 36, 49, 64, 81, 100)),
  start_at timestamptz not null,
  reveal_at timestamptz not null,
  revealed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (reveal_at > start_at)
);

create table public.mosaic_v3_members (
  mosaic_id uuid not null references public.mosaic_v3_mosaics(id) on delete cascade,
  profile_id uuid not null references public.mosaic_v3_profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('creator', 'member')),
  joined_at timestamptz not null default now(),
  primary key (mosaic_id, profile_id)
);

create unique index mosaic_v3_single_creator on public.mosaic_v3_members(mosaic_id) where role = 'creator';

create table public.mosaic_v3_kindness_activities (
  id uuid primary key default gen_random_uuid(),
  mosaic_id uuid not null references public.mosaic_v3_mosaics(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  purpose text not null default '' check (char_length(purpose) <= 400),
  sort_order integer not null check (sort_order >= 0),
  created_at timestamptz not null default now(),
  unique (mosaic_id, sort_order),
  unique (id, mosaic_id)
);

create table public.mosaic_v3_kindness_contributions (
  id uuid primary key default gen_random_uuid(),
  mosaic_id uuid not null references public.mosaic_v3_mosaics(id) on delete cascade,
  activity_id uuid not null,
  participant_id uuid not null references public.mosaic_v3_profiles(id) on delete cascade,
  tile_position integer not null check (tile_position >= 0),
  note text check (note is null or char_length(note) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (activity_id, mosaic_id) references public.mosaic_v3_kindness_activities(id, mosaic_id) on delete cascade,
  unique (mosaic_id, activity_id, participant_id),
  unique (mosaic_id, tile_position)
);

create table public.mosaic_v3_event_photos (
  id uuid primary key,
  mosaic_id uuid not null references public.mosaic_v3_mosaics(id) on delete cascade,
  photographer_id uuid not null references public.mosaic_v3_profiles(id) on delete cascade,
  storage_path text not null unique,
  mime_type text not null check (mime_type = 'image/jpeg'),
  byte_count integer not null check (byte_count between 1 and 12582912),
  pixel_width integer not null check (pixel_width between 1 and 12000),
  pixel_height integer not null check (pixel_height between 1 and 12000),
  film_look_id text not null check (film_look_id in ('sunwashed', 'garden', 'afterglow')),
  state text not null check (state in ('upload_pending', 'eligible', 'quarantined')),
  captured_at timestamptz not null default now(),
  finalized_at timestamptz,
  quarantined_at timestamptz,
  check (storage_path = mosaic_id::text || '/' || photographer_id::text || '/' || id::text || '.jpg')
);

create index mosaic_v3_event_photos_gallery_idx on public.mosaic_v3_event_photos(mosaic_id, captured_at) where state = 'eligible';
create index mosaic_v3_event_photos_shot_count_idx on public.mosaic_v3_event_photos(mosaic_id, photographer_id) where state in ('upload_pending', 'eligible');

create table public.mosaic_v3_event_photo_reports (
  id uuid primary key default gen_random_uuid(),
  photo_id uuid not null references public.mosaic_v3_event_photos(id) on delete cascade,
  reporter_id uuid not null references public.mosaic_v3_profiles(id) on delete cascade,
  reason text not null check (char_length(btrim(reason)) between 3 and 300),
  created_at timestamptz not null default now(),
  unique (photo_id, reporter_id)
);

create table public.mosaic_v3_user_blocks (
  blocker_id uuid not null references public.mosaic_v3_profiles(id) on delete cascade,
  blocked_id uuid not null references public.mosaic_v3_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table private.mosaic_v3_artwork_reveal_packages (
  mosaic_id uuid primary key references public.mosaic_v3_mosaics(id) on delete cascade,
  ciphertext_path text not null,
  checksum text not null,
  encryption_key text not null,
  nonce text not null,
  created_at timestamptz not null default now()
);

insert into public.mosaic_v3_artwork_catalog (id, title, artist, asset_name, source_url, license, alt_text, reviewed_at) values
('a0000000-0000-4000-8000-000000000001', 'Water Lilies', 'Claude Monet', 'OnboardingWaterLilies', 'https://www.artic.edu/artworks/16568/water-lilies', 'CC0 / Public Domain', 'Water lilies floating across a blue-green pond', now()),
('a0000000-0000-4000-8000-000000000002', 'Paris Street; Rainy Day', 'Gustave Caillebotte', 'OnboardingParisStreet', 'https://www.artic.edu/artworks/20684/paris-street-rainy-day', 'CC0 / Public Domain', 'People walking with umbrellas on a broad Paris street', now()),
('a0000000-0000-4000-8000-000000000003', 'A Sunday on La Grande Jatte', 'Georges Seurat', 'OnboardingLaGrandeJatte', 'https://www.artic.edu/artworks/27992/a-sunday-on-la-grande-jatte-1884', 'CC0 / Public Domain', 'People relaxing by the river on a sunny afternoon', now()),
('a0000000-0000-4000-8000-000000000004', 'The Bedroom', 'Vincent van Gogh', 'OnboardingBedroom', 'https://www.artic.edu/artworks/28560/the-bedroom', 'CC0 / Public Domain', 'A colorful painted bedroom with a wooden bed', now());

create or replace function private.v3_is_mosaic_member(target_mosaic uuid, target_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select target_user is not null and exists (
    select 1 from public.mosaic_v3_members mm where mm.mosaic_id = target_mosaic and mm.profile_id = target_user
  );
$$;

create or replace function private.v3_is_mosaic_creator(target_mosaic uuid, target_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select target_user is not null and exists (
    select 1 from public.mosaic_v3_mosaics m where m.id = target_mosaic and m.creator_id = target_user
  );
$$;

create or replace function private.v3_mosaic_revealed(target_mosaic uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.mosaic_v3_mosaics m where m.id = target_mosaic and now() >= m.reveal_at);
$$;

create or replace function private.v3_can_read_artwork_package(target_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1
    from private.mosaic_v3_artwork_reveal_packages package
    join public.mosaic_v3_mosaics mosaic on mosaic.id = package.mosaic_id
    join public.mosaic_v3_members member on member.mosaic_id = mosaic.id
    where package.ciphertext_path = target_path
      and member.profile_id = auth.uid()
      and now() >= mosaic.reveal_at
  );
$$;

create or replace function private.v3_artwork_json(art public.mosaic_v3_artwork_catalog)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', art.id, 'title', art.title, 'artist', art.artist, 'assetName', art.asset_name,
    'sourceURL', art.source_url, 'license', art.license, 'altText', art.alt_text
  );
$$;

create or replace function private.v3_sealed_artwork_json()
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object(
    'id', '00000000-0000-0000-0000-000000000000'::uuid,
    'title', 'Sealed until reveal',
    'artist', 'Mosaic',
    'assetName', 'SealedArtwork',
    'sourceURL', 'https://mosaic.invalid/sealed',
    'license', 'Revealed with the artwork',
    'altText', 'Sealed ceramic artwork'
  );
$$;

create or replace function private.v3_summary_json(m public.mosaic_v3_mosaics)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', m.id, 'name', m.name, 'communityName', m.community_name, 'description', m.description,
    'startAt', m.start_at, 'revealAt', m.reveal_at, 'goal', m.tile_goal,
    'contributionCount', (select count(*) from public.mosaic_v3_kindness_contributions c where c.mosaic_id = m.id),
    'photoCount', (select count(*) from public.mosaic_v3_event_photos p where p.mosaic_id = m.id and p.state = 'eligible'),
    'filmLookID', m.film_look_id, 'shotLimit', m.shot_limit,
    'artwork', case when now() >= m.reveal_at then private.v3_artwork_json(a) else private.v3_sealed_artwork_json() end,
    'isCreator', m.creator_id = auth.uid()
  ) from public.mosaic_v3_artwork_catalog a where a.id = m.artwork_id;
$$;

create or replace function private.v3_event_json(m public.mosaic_v3_mosaics)
returns jsonb language sql stable security definer set search_path = '' as $$
  select private.v3_summary_json(m) || jsonb_build_object(
    'creatorID', m.creator_id,
    'invitationCode', m.invitation_code,
    'invitationURL', 'mosaic://join/' || m.invitation_code,
    'activities', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'mosaicID', a.mosaic_id, 'title', a.title, 'purpose', a.purpose,
        'sortOrder', a.sort_order,
        'participantCompleted', exists(select 1 from public.mosaic_v3_kindness_contributions mine where mine.activity_id = a.id and mine.participant_id = auth.uid())
      ) order by a.sort_order) from public.mosaic_v3_kindness_activities a where a.mosaic_id = m.id
    ), '[]'::jsonb),
    'contributions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'mosaicID', c.mosaic_id, 'activityID', c.activity_id, 'participantID', c.participant_id,
        'contributorDisplayName', case when now() >= m.reveal_at or c.participant_id = auth.uid() then p.display_name else null end,
        'tilePosition', c.tile_position,
        'note', case when now() >= m.reveal_at or c.participant_id = auth.uid() then c.note else null end,
        'createdAt', c.created_at, 'updatedAt', c.updated_at, 'isMine', c.participant_id = auth.uid()
      ) order by c.tile_position)
      from public.mosaic_v3_kindness_contributions c join public.mosaic_v3_profiles p on p.id = c.participant_id
      where c.mosaic_id = m.id and (now() >= m.reveal_at or c.participant_id = auth.uid())
    ), '[]'::jsonb),
    'contributionCount', (select count(*) from public.mosaic_v3_kindness_contributions c where c.mosaic_id = m.id),
    'occupiedTilePositions', coalesce((select jsonb_agg(c.tile_position order by c.tile_position) from public.mosaic_v3_kindness_contributions c where c.mosaic_id = m.id), '[]'::jsonb),
    'photos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', ep.id, 'mosaicID', ep.mosaic_id, 'photographerID', ep.photographer_id,
        'photographerDisplayName', pp.display_name, 'filmLookID', ep.film_look_id,
        'capturedAt', ep.captured_at, 'state', ep.state, 'storagePath', ep.storage_path,
        'localURL', null, 'signedURL', null, 'pixelWidth', ep.pixel_width, 'pixelHeight', ep.pixel_height,
        'isMine', ep.photographer_id = auth.uid()
      ) order by ep.captured_at)
      from public.mosaic_v3_event_photos ep join public.mosaic_v3_profiles pp on pp.id = ep.photographer_id
      where ep.mosaic_id = m.id and ep.state = 'eligible'
        and (ep.photographer_id = auth.uid() or now() >= m.reveal_at)
        and not exists (select 1 from public.mosaic_v3_user_blocks b where b.blocker_id = auth.uid() and b.blocked_id = ep.photographer_id)
    ), '[]'::jsonb),
    'memberCount', (select count(*) from public.mosaic_v3_members mm where mm.mosaic_id = m.id),
    'isCreator', m.creator_id = auth.uid()
  );
$$;

revoke all on function private.v3_is_mosaic_member(uuid,uuid) from public, anon, authenticated;
revoke all on function private.v3_is_mosaic_creator(uuid,uuid) from public, anon, authenticated;
revoke all on function private.v3_mosaic_revealed(uuid) from public, anon, authenticated;
revoke all on function private.v3_can_read_artwork_package(text) from public, anon, authenticated;
revoke all on function private.v3_artwork_json(public.mosaic_v3_artwork_catalog) from public, anon, authenticated;
revoke all on function private.v3_sealed_artwork_json() from public, anon, authenticated;
revoke all on function private.v3_summary_json(public.mosaic_v3_mosaics) from public, anon, authenticated;
revoke all on function private.v3_event_json(public.mosaic_v3_mosaics) from public, anon, authenticated;
grant execute on function private.v3_is_mosaic_member(uuid,uuid) to authenticated;
grant execute on function private.v3_is_mosaic_creator(uuid,uuid) to authenticated;
grant execute on function private.v3_mosaic_revealed(uuid) to authenticated;
grant execute on function private.v3_can_read_artwork_package(text) to authenticated;
grant execute on function private.v3_summary_json(public.mosaic_v3_mosaics) to authenticated;

alter table public.mosaic_v3_profiles enable row level security;
alter table public.mosaic_v3_artwork_catalog enable row level security;
alter table public.mosaic_v3_mosaics enable row level security;
alter table public.mosaic_v3_members enable row level security;
alter table public.mosaic_v3_kindness_activities enable row level security;
alter table public.mosaic_v3_kindness_contributions enable row level security;
alter table public.mosaic_v3_event_photos enable row level security;
alter table public.mosaic_v3_event_photo_reports enable row level security;
alter table public.mosaic_v3_user_blocks enable row level security;

revoke all on table public.mosaic_v3_profiles from anon, authenticated;
revoke all on table public.mosaic_v3_artwork_catalog from anon, authenticated;
revoke all on table public.mosaic_v3_mosaics from anon, authenticated;
revoke all on table public.mosaic_v3_members from anon, authenticated;
revoke all on table public.mosaic_v3_kindness_activities from anon, authenticated;
revoke all on table public.mosaic_v3_kindness_contributions from anon, authenticated;
revoke all on table public.mosaic_v3_event_photos from anon, authenticated;
revoke all on table public.mosaic_v3_event_photo_reports from anon, authenticated;
revoke all on table public.mosaic_v3_user_blocks from anon, authenticated;
grant select, insert, update on public.mosaic_v3_profiles to authenticated;
grant select on public.mosaic_v3_artwork_catalog to anon, authenticated;
grant select on public.mosaic_v3_mosaics, public.mosaic_v3_members, public.mosaic_v3_kindness_activities, public.mosaic_v3_kindness_contributions, public.mosaic_v3_event_photos, public.mosaic_v3_event_photo_reports, public.mosaic_v3_user_blocks to authenticated;

create policy profiles_select_self on public.mosaic_v3_profiles for select to authenticated using ((select auth.uid()) = id);
create policy profiles_insert_self on public.mosaic_v3_profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_update_self on public.mosaic_v3_profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy artworks_read_reviewed on public.mosaic_v3_artwork_catalog for select to anon, authenticated using (enabled);
create policy mosaics_read_members on public.mosaic_v3_mosaics for select to authenticated using (private.v3_is_mosaic_member(id));
create policy members_read_members on public.mosaic_v3_members for select to authenticated using (private.v3_is_mosaic_member(mosaic_id));
create policy activities_read_members on public.mosaic_v3_kindness_activities for select to authenticated using (private.v3_is_mosaic_member(mosaic_id));
create policy contributions_read_boundary on public.mosaic_v3_kindness_contributions for select to authenticated using (
  private.v3_is_mosaic_member(mosaic_id) and (participant_id = (select auth.uid()) or private.v3_mosaic_revealed(mosaic_id))
);
create policy photos_read_boundary on public.mosaic_v3_event_photos for select to authenticated using (
  private.v3_is_mosaic_member(mosaic_id)
  and (
    (photographer_id = (select auth.uid()) and state in ('upload_pending', 'eligible'))
    or (state = 'eligible' and private.v3_mosaic_revealed(mosaic_id))
  )
  and not exists (select 1 from public.mosaic_v3_user_blocks b where b.blocker_id = (select auth.uid()) and b.blocked_id = photographer_id)
);
create policy reports_read_self on public.mosaic_v3_event_photo_reports for select to authenticated using (reporter_id = (select auth.uid()));
create policy blocks_read_self on public.mosaic_v3_user_blocks for select to authenticated using (blocker_id = (select auth.uid()));

create or replace function public.v3_list_mosaics()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(private.v3_summary_json(m) order by m.reveal_at), '[]'::jsonb)
  from public.mosaic_v3_mosaics m where private.v3_is_mosaic_member(m.id);
$$;

create or replace function public.v3_resolve_invitation("invitationCode" text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare m public.mosaic_v3_mosaics;
begin
  select * into m from public.mosaic_v3_mosaics where invitation_code = upper(regexp_replace("invitationCode", '[^A-Za-z0-9]', '', 'g'));
  if m.id is null then raise exception 'invalid_invitation' using errcode = 'P0001'; end if;
  if now() >= m.reveal_at then raise exception 'joining_closed' using errcode = 'P0001'; end if;
  return jsonb_build_object(
    'code', m.invitation_code, 'name', m.name, 'communityName', m.community_name,
    'description', m.description, 'revealAt', m.reveal_at, 'artwork', private.v3_sealed_artwork_json(),
    'memberCount', (select count(*) from public.mosaic_v3_members mm where mm.mosaic_id = m.id)
  );
end;
$$;

create or replace function public.v3_create_mosaic(payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare m public.mosaic_v3_mosaics; activity jsonb; code text;
begin
  if auth.uid() is null then raise exception 'account_required' using errcode = 'P0001'; end if;
  if not exists(select 1 from public.mosaic_v3_profiles where id = auth.uid()) then raise exception 'display_name_required' using errcode = 'P0001'; end if;
  if jsonb_array_length(coalesce(payload->'activities', '[]'::jsonb)) < 1 then raise exception 'activity_required' using errcode = 'P0001'; end if;
  code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  insert into public.mosaic_v3_mosaics(creator_id, name, community_name, description, invitation_code, artwork_id, film_look_id, shot_limit, tile_goal, start_at, reveal_at)
  values (auth.uid(), btrim(payload->>'name'), btrim(payload->>'communityName'), btrim(coalesce(payload->>'description','')), code,
          (payload->>'artworkID')::uuid, payload->>'filmLookID', (payload->>'shotLimit')::int, (payload->>'goal')::int,
          (payload->>'startAt')::timestamptz, (payload->>'revealAt')::timestamptz) returning * into m;
  insert into public.mosaic_v3_members(mosaic_id, profile_id, role) values (m.id, auth.uid(), 'creator');
  for activity in select value from jsonb_array_elements(payload->'activities') loop
    insert into public.mosaic_v3_kindness_activities(mosaic_id, title, purpose, sort_order)
    values (m.id, btrim(activity->>'title'), btrim(coalesce(activity->>'purpose','')), (activity->>'sortOrder')::int);
  end loop;
  return private.v3_event_json(m);
end;
$$;

create or replace function public.v3_join_mosaic("invitationCode" text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare m public.mosaic_v3_mosaics;
begin
  if auth.uid() is null or not exists(select 1 from public.mosaic_v3_profiles where id = auth.uid()) then raise exception 'account_required' using errcode = 'P0001'; end if;
  select * into m from public.mosaic_v3_mosaics where invitation_code = upper(regexp_replace("invitationCode", '[^A-Za-z0-9]', '', 'g')) for update;
  if m.id is null then raise exception 'invalid_invitation' using errcode = 'P0001'; end if;
  if now() >= m.reveal_at then raise exception 'joining_closed' using errcode = 'P0001'; end if;
  insert into public.mosaic_v3_members(mosaic_id, profile_id) values (m.id, auth.uid()) on conflict do nothing;
  return private.v3_event_json(m);
end;
$$;

create or replace function public.v3_load_mosaic("mosaicID" uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare m public.mosaic_v3_mosaics;
begin
  if not private.v3_is_mosaic_member("mosaicID") then raise exception 'not_a_member' using errcode = '42501'; end if;
  select * into strict m from public.mosaic_v3_mosaics where id = "mosaicID";
  return private.v3_event_json(m);
end;
$$;

create or replace function public.v3_update_mosaic("mosaicID" uuid, name text, description text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare m public.mosaic_v3_mosaics;
begin
  select * into strict m from public.mosaic_v3_mosaics where id = "mosaicID" for update;
  if m.creator_id <> auth.uid() then raise exception 'creator_required' using errcode = '42501'; end if;
  if now() >= m.reveal_at then raise exception 'mosaic_revealed' using errcode = 'P0001'; end if;
  update public.mosaic_v3_mosaics set name = btrim(v3_update_mosaic.name), description = btrim(v3_update_mosaic.description), updated_at = now()
  where id = "mosaicID" returning * into m;
  return private.v3_event_json(m);
end;
$$;

create or replace function public.v3_delete_mosaic("mosaicID" uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
begin
  if not private.v3_is_mosaic_creator("mosaicID") then raise exception 'creator_required' using errcode = '42501'; end if;
  delete from public.mosaic_v3_mosaics where id = "mosaicID";
  return found;
end;
$$;

create or replace function public.v3_complete_activity("mosaicID" uuid, "activityID" uuid, note text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare m public.mosaic_v3_mosaics; position integer; c public.mosaic_v3_kindness_contributions; p public.mosaic_v3_profiles;
begin
  if not private.v3_is_mosaic_member("mosaicID") then raise exception 'not_a_member' using errcode = '42501'; end if;
  select * into strict m from public.mosaic_v3_mosaics where id = "mosaicID" for update;
  if now() < m.start_at or now() >= m.reveal_at then raise exception 'contribution_closed' using errcode = 'P0001'; end if;
  if not exists(select 1 from public.mosaic_v3_kindness_activities a where a.id = "activityID" and a.mosaic_id = m.id) then raise exception 'invalid_activity' using errcode = 'P0001'; end if;
  if exists(select 1 from public.mosaic_v3_kindness_contributions x where x.mosaic_id = m.id and x.activity_id = "activityID" and x.participant_id = auth.uid()) then raise exception 'already_completed' using errcode = '23505'; end if;
  select candidate into position from generate_series(0, m.tile_goal - 1) candidate
  where not exists(select 1 from public.mosaic_v3_kindness_contributions used where used.mosaic_id = m.id and used.tile_position = candidate)
  order by candidate limit 1;
  if position is null then raise exception 'board_full' using errcode = 'P0001'; end if;
  insert into public.mosaic_v3_kindness_contributions(mosaic_id, activity_id, participant_id, tile_position, note)
  values (m.id, "activityID", auth.uid(), position, nullif(btrim(note), '')) returning * into c;
  select * into p from public.mosaic_v3_profiles where id = auth.uid();
  return jsonb_build_object('id',c.id,'mosaicID',c.mosaic_id,'activityID',c.activity_id,'participantID',c.participant_id,
    'contributorDisplayName',p.display_name,'tilePosition',c.tile_position,'note',c.note,'createdAt',c.created_at,'updatedAt',c.updated_at,'isMine',true);
exception when unique_violation then raise exception 'already_completed_or_capacity_race' using errcode = '23505';
end;
$$;

create or replace function public.v3_update_contribution("contributionID" uuid, note text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare c public.mosaic_v3_kindness_contributions; m public.mosaic_v3_mosaics; p public.mosaic_v3_profiles;
begin
  select * into strict c from public.mosaic_v3_kindness_contributions where id = "contributionID" for update;
  select * into strict m from public.mosaic_v3_mosaics where id = c.mosaic_id;
  if c.participant_id <> auth.uid() then raise exception 'owner_required' using errcode = '42501'; end if;
  if now() >= m.reveal_at then raise exception 'mosaic_revealed' using errcode = 'P0001'; end if;
  update public.mosaic_v3_kindness_contributions set note = nullif(btrim(v3_update_contribution.note), ''), updated_at = now()
  where id = c.id returning * into c;
  select * into p from public.mosaic_v3_profiles where id = c.participant_id;
  return jsonb_build_object('id',c.id,'mosaicID',c.mosaic_id,'activityID',c.activity_id,'participantID',c.participant_id,
    'contributorDisplayName',p.display_name,'tilePosition',c.tile_position,'note',c.note,'createdAt',c.created_at,'updatedAt',c.updated_at,'isMine',true);
end;
$$;

create or replace function public.v3_withdraw_contribution("contributionID" uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare c public.mosaic_v3_kindness_contributions; reveal_time timestamptz;
begin
  select * into strict c from public.mosaic_v3_kindness_contributions where id = "contributionID" for update;
  if c.participant_id <> auth.uid() then raise exception 'owner_required' using errcode = '42501'; end if;
  select reveal_at into reveal_time from public.mosaic_v3_mosaics where id = c.mosaic_id;
  if now() >= reveal_time then raise exception 'mosaic_revealed' using errcode = 'P0001'; end if;
  delete from public.mosaic_v3_kindness_contributions where id = c.id;
  return true;
end;
$$;

create or replace function public.v3_prepare_event_photo("mosaicID" uuid, "photoID" uuid, "mimeType" text, "byteCount" integer, "pixelWidth" integer, "pixelHeight" integer)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare m public.mosaic_v3_mosaics; path text; used integer; existing public.mosaic_v3_event_photos;
begin
  if not private.v3_is_mosaic_member("mosaicID") then raise exception 'not_a_member' using errcode = '42501'; end if;
  select * into strict m from public.mosaic_v3_mosaics where id = "mosaicID" for update;
  if now() >= m.reveal_at then raise exception 'photography_closed' using errcode = 'P0001'; end if;
  if "mimeType" <> 'image/jpeg' or "byteCount" not between 1 and 12582912 then raise exception 'invalid_photo' using errcode = 'P0001'; end if;
  select * into existing from public.mosaic_v3_event_photos where id="photoID";
  if existing.id is not null then
    if existing.mosaic_id<>m.id or existing.photographer_id<>auth.uid() or existing.mime_type<>"mimeType"
       or existing.byte_count<>"byteCount" or existing.pixel_width<>"pixelWidth" or existing.pixel_height<>"pixelHeight" then
      raise exception 'photo_id_conflict' using errcode='23505';
    end if;
    return jsonb_build_object('photoID',existing.id,'path',existing.storage_path,'token','');
  end if;
  select count(*) into used from public.mosaic_v3_event_photos ep where ep.mosaic_id = m.id and ep.photographer_id = auth.uid() and ep.state in ('upload_pending','eligible');
  if used >= m.shot_limit then raise exception 'shot_limit_reached' using errcode = 'P0001'; end if;
  path := m.id::text || '/' || auth.uid()::text || '/' || "photoID"::text || '.jpg';
  insert into public.mosaic_v3_event_photos(id,mosaic_id,photographer_id,storage_path,mime_type,byte_count,pixel_width,pixel_height,film_look_id,state)
  values("photoID",m.id,auth.uid(),path,"mimeType","byteCount","pixelWidth","pixelHeight",m.film_look_id,'upload_pending');
  return jsonb_build_object('photoID',"photoID",'path',path,'token','');
end;
$$;

create or replace function public.v3_finalize_event_photo("photoID" uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare ep public.mosaic_v3_event_photos; p public.mosaic_v3_profiles;
begin
  select * into strict ep from public.mosaic_v3_event_photos where id = "photoID" for update;
  if ep.photographer_id <> auth.uid() then raise exception 'owner_required' using errcode = '42501'; end if;
  if private.v3_mosaic_revealed(ep.mosaic_id) then raise exception 'photography_closed' using errcode = 'P0001'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id = 'event-photos' and o.name = ep.storage_path) then raise exception 'upload_missing' using errcode = 'P0001'; end if;
  update public.mosaic_v3_event_photos set state='eligible', finalized_at=now() where id=ep.id returning * into ep;
  select * into p from public.mosaic_v3_profiles where id=ep.photographer_id;
  return jsonb_build_object('id',ep.id,'mosaicID',ep.mosaic_id,'photographerID',ep.photographer_id,'photographerDisplayName',p.display_name,
    'filmLookID',ep.film_look_id,'capturedAt',ep.captured_at,'state',ep.state,'storagePath',ep.storage_path,'localURL',null,'signedURL',null,
    'pixelWidth',ep.pixel_width,'pixelHeight',ep.pixel_height,'isMine',true);
end;
$$;

create or replace function public.v3_prepare_delete_event_photo("photoID" uuid)
returns text language plpgsql stable security definer set search_path = '' as $$
declare ep public.mosaic_v3_event_photos;
begin
  select * into strict ep from public.mosaic_v3_event_photos where id="photoID";
  if ep.photographer_id <> auth.uid() then raise exception 'owner_required' using errcode='42501'; end if;
  return ep.storage_path;
end;
$$;

create or replace function public.v3_delete_event_photo("photoID" uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare ep public.mosaic_v3_event_photos;
begin
  select * into strict ep from public.mosaic_v3_event_photos where id="photoID" for update;
  if ep.photographer_id <> auth.uid() then raise exception 'owner_required' using errcode='42501'; end if;
  delete from public.mosaic_v3_event_photos where id=ep.id;
  return true;
end;
$$;

create or replace function public.v3_report_event_photo("photoID" uuid, reason text)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare ep public.mosaic_v3_event_photos;
begin
  select * into strict ep from public.mosaic_v3_event_photos where id="photoID" for update;
  if not private.v3_is_mosaic_member(ep.mosaic_id) or not private.v3_mosaic_revealed(ep.mosaic_id) then raise exception 'not_allowed' using errcode='42501'; end if;
  if ep.photographer_id = auth.uid() then raise exception 'cannot_report_self' using errcode='P0001'; end if;
  insert into public.mosaic_v3_event_photo_reports(photo_id,reporter_id,reason) values(ep.id,auth.uid(),btrim(reason)) on conflict do nothing;
  update public.mosaic_v3_event_photos set state='quarantined',quarantined_at=now() where id=ep.id;
  return true;
end;
$$;

create or replace function public.v3_block_user("blockedID" uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
begin
  if auth.uid() is null or "blockedID"=auth.uid() then raise exception 'invalid_block' using errcode='P0001'; end if;
  insert into public.mosaic_v3_user_blocks(blocker_id,blocked_id) values(auth.uid(),"blockedID") on conflict do nothing;
  return true;
end;
$$;

create or replace function public.v3_unblock_user("blockedID" uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
begin delete from public.mosaic_v3_user_blocks where blocker_id=auth.uid() and blocked_id="blockedID"; return true; end;
$$;

create or replace function public.v3_list_blocked_users()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'displayName',p.display_name,'blockedAt',b.created_at) order by b.created_at desc),'[]'::jsonb)
  from public.mosaic_v3_user_blocks b join public.mosaic_v3_profiles p on p.id=b.blocked_id where b.blocker_id=auth.uid();
$$;

create or replace function public.v3_release_artwork("mosaicID" uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare package private.mosaic_v3_artwork_reveal_packages;
begin
  if not private.v3_is_mosaic_member("mosaicID") or not private.v3_mosaic_revealed("mosaicID") then raise exception 'reveal_locked' using errcode='42501'; end if;
  select * into strict package from private.mosaic_v3_artwork_reveal_packages where mosaic_id="mosaicID";
  return jsonb_build_object('ciphertextPath',package.ciphertext_path,'checksum',package.checksum,'key',package.encryption_key,'nonce',package.nonce);
end;
$$;

create or replace function public.v3_pending_artwork_packages()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'mosaicID',m.id,
    'assetName',a.asset_name
  ) order by m.created_at),'[]'::jsonb)
  from public.mosaic_v3_mosaics m
  join public.mosaic_v3_artwork_catalog a on a.id=m.artwork_id
  left join private.mosaic_v3_artwork_reveal_packages package on package.mosaic_id=m.id
  where package.mosaic_id is null;
$$;

create or replace function public.v3_register_artwork_package(
  "mosaicID" uuid,
  "ciphertextPath" text,
  checksum text,
  "encryptionKey" text,
  nonce text
)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
begin
  if not exists(select 1 from public.mosaic_v3_mosaics where id="mosaicID") then
    raise exception 'mosaic_not_found' using errcode='P0001';
  end if;
  if "ciphertextPath" <> "mosaicID"::text || '/artwork.aesgcm'
     or checksum !~ '^[0-9a-f]{64}$'
     or char_length("encryptionKey") < 40
     or char_length(nonce) < 16 then
    raise exception 'invalid_artwork_package' using errcode='P0001';
  end if;
  insert into private.mosaic_v3_artwork_reveal_packages(mosaic_id,ciphertext_path,checksum,encryption_key,nonce)
  values("mosaicID","ciphertextPath",checksum,"encryptionKey",nonce)
  on conflict(mosaic_id) do update set
    ciphertext_path=excluded.ciphertext_path,
    checksum=excluded.checksum,
    encryption_key=excluded.encryption_key,
    nonce=excluded.nonce,
    created_at=now();
  return true;
end;
$$;

create or replace function public.v3_delete_account()
returns boolean language plpgsql volatile security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'account_required' using errcode='42501'; end if;
  delete from auth.users where id=auth.uid();
  return true;
end;
$$;

create or replace function private.v3_mark_due_mosaics_revealed()
returns integer language plpgsql volatile security definer set search_path = '' as $$
declare changed integer;
begin
  update public.mosaic_v3_mosaics set revealed_at=reveal_at,updated_at=now() where revealed_at is null and reveal_at<=now();
  get diagnostics changed = row_count;
  return changed;
end;
$$;

revoke all on function public.v3_list_mosaics() from public, anon, authenticated;
revoke all on function public.v3_resolve_invitation(text) from public, anon, authenticated;
revoke all on function public.v3_create_mosaic(jsonb) from public, anon, authenticated;
revoke all on function public.v3_join_mosaic(text) from public, anon, authenticated;
revoke all on function public.v3_load_mosaic(uuid) from public, anon, authenticated;
revoke all on function public.v3_update_mosaic(uuid,text,text) from public, anon, authenticated;
revoke all on function public.v3_delete_mosaic(uuid) from public, anon, authenticated;
revoke all on function public.v3_complete_activity(uuid,uuid,text) from public, anon, authenticated;
revoke all on function public.v3_update_contribution(uuid,text) from public, anon, authenticated;
revoke all on function public.v3_withdraw_contribution(uuid) from public, anon, authenticated;
revoke all on function public.v3_prepare_event_photo(uuid,uuid,text,integer,integer,integer) from public, anon, authenticated;
revoke all on function public.v3_finalize_event_photo(uuid) from public, anon, authenticated;
revoke all on function public.v3_prepare_delete_event_photo(uuid) from public, anon, authenticated;
revoke all on function public.v3_delete_event_photo(uuid) from public, anon, authenticated;
revoke all on function public.v3_report_event_photo(uuid,text) from public, anon, authenticated;
revoke all on function public.v3_block_user(uuid) from public, anon, authenticated;
revoke all on function public.v3_unblock_user(uuid) from public, anon, authenticated;
revoke all on function public.v3_list_blocked_users() from public, anon, authenticated;
revoke all on function public.v3_release_artwork(uuid) from public, anon, authenticated;
revoke all on function public.v3_delete_account() from public, anon, authenticated;
revoke all on function public.v3_pending_artwork_packages() from public, anon, authenticated;
revoke all on function public.v3_register_artwork_package(uuid,text,text,text,text) from public, anon, authenticated;
grant execute on function public.v3_resolve_invitation(text) to anon, authenticated;
grant execute on function public.v3_list_mosaics() to authenticated;
grant execute on function public.v3_create_mosaic(jsonb) to authenticated;
grant execute on function public.v3_join_mosaic(text) to authenticated;
grant execute on function public.v3_load_mosaic(uuid) to authenticated;
grant execute on function public.v3_update_mosaic(uuid,text,text) to authenticated;
grant execute on function public.v3_delete_mosaic(uuid) to authenticated;
grant execute on function public.v3_complete_activity(uuid,uuid,text) to authenticated;
grant execute on function public.v3_update_contribution(uuid,text) to authenticated;
grant execute on function public.v3_withdraw_contribution(uuid) to authenticated;
grant execute on function public.v3_prepare_event_photo(uuid,uuid,text,integer,integer,integer) to authenticated;
grant execute on function public.v3_finalize_event_photo(uuid) to authenticated;
grant execute on function public.v3_prepare_delete_event_photo(uuid) to authenticated;
grant execute on function public.v3_delete_event_photo(uuid) to authenticated;
grant execute on function public.v3_report_event_photo(uuid,text) to authenticated;
grant execute on function public.v3_block_user(uuid) to authenticated;
grant execute on function public.v3_unblock_user(uuid) to authenticated;
grant execute on function public.v3_list_blocked_users() to authenticated;
grant execute on function public.v3_release_artwork(uuid) to authenticated;
grant execute on function public.v3_delete_account() to authenticated;
grant execute on function public.v3_pending_artwork_packages() to service_role;
grant execute on function public.v3_register_artwork_package(uuid,text,text,text,text) to service_role;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('event-photos','event-photos',false,12582912,array['image/jpeg'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('artwork-reveal-packages','artwork-reveal-packages',false,20971520,array['application/octet-stream'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy event_photos_storage_insert on storage.objects for insert to authenticated with check (
  bucket_id='event-photos' and exists(
    select 1 from public.mosaic_v3_event_photos ep where ep.storage_path=name and ep.photographer_id=(select auth.uid())
      and ep.state='upload_pending' and not private.v3_mosaic_revealed(ep.mosaic_id)
  )
);
create policy event_photos_storage_select on storage.objects for select to authenticated using (
  bucket_id='event-photos' and exists(
    select 1 from public.mosaic_v3_event_photos ep where ep.storage_path=name and ep.state='eligible' and private.v3_is_mosaic_member(ep.mosaic_id)
      and (ep.photographer_id=(select auth.uid()) or private.v3_mosaic_revealed(ep.mosaic_id))
      and not exists(select 1 from public.mosaic_v3_user_blocks b where b.blocker_id=(select auth.uid()) and b.blocked_id=ep.photographer_id)
  )
);
create policy event_photos_storage_delete on storage.objects for delete to authenticated using (
  bucket_id='event-photos' and exists(
    select 1 from public.mosaic_v3_event_photos ep
    where ep.storage_path=name and ep.photographer_id=(select auth.uid())
  )
);
create policy artwork_packages_storage_select on storage.objects for select to authenticated using (
  bucket_id='artwork-reveal-packages' and private.v3_can_read_artwork_package(name)
);

select cron.schedule('mosaic-v3-fixed-reveal','* * * * *',$$select private.v3_mark_due_mosaics_revealed();$$);
