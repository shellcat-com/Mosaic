create type public.artwork_mode as enum ('legacy', 'museum');

alter table public.challenges
  add column artwork_mode public.artwork_mode not null default 'legacy',
  add column board_side integer,
  add column artwork_collection text,
  add column artwork_palette text[] not null default '{}',
  add column artwork_catalog_revision integer,
  add column artwork_package_revision integer,
  add column artwork_locked_at timestamptz;

alter table public.challenges
  add constraint challenges_museum_geometry_check check (
    artwork_mode = 'legacy'
    or (
      board_side between 3 and 10
      and goal = board_side * board_side
      and goal in (9, 16, 25, 36, 49, 64, 81, 100)
      and artwork_collection is not null
      and cardinality(artwork_palette) between 3 and 6
      and artwork_catalog_revision is not null
      and artwork_catalog_revision > 0
      and artwork_package_revision is not null
      and artwork_package_revision > 0
    )
  );

comment on column public.challenges.artwork_mode is
  'Legacy keeps the bundled procedural renderer. Museum uses a private challenge-specific artwork assignment.';
comment on column public.challenges.artwork_collection is
  'Participant-safe collection label. It does not identify the selected artwork.';
comment on column public.challenges.artwork_palette is
  'Participant-safe sealed palette. It must never contain artwork fragments.';

create table public.artwork_catalog (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  museum_artwork_id bigint not null unique,
  image_id uuid not null unique,
  title text not null,
  artist_display text not null,
  date_display text not null,
  source_url text not null,
  alt_text text not null,
  collection text not null,
  dominant_colors text[] not null,
  source_width integer not null,
  source_height integer not null,
  crop_x numeric(7,6) not null,
  crop_y numeric(7,6) not null,
  crop_width numeric(7,6) not null,
  crop_height numeric(7,6) not null,
  is_public_domain boolean not null,
  license_label text not null default 'CC0 Public Domain Designation',
  catalog_revision integer not null default 1,
  manifest_checksum text not null,
  content_reviewed_at timestamptz not null,
  crop_reviewed_at timestamptz not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint artwork_catalog_slug_check check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint artwork_catalog_public_domain_check check (is_public_domain),
  constraint artwork_catalog_source_check check (source_url ~ '^https://www.artic.edu/artworks/[0-9]+'),
  constraint artwork_catalog_text_check check (
    char_length(title) > 0 and char_length(artist_display) > 0
    and char_length(date_display) > 0 and char_length(alt_text) > 0
  ),
  constraint artwork_catalog_collection_check check (collection in (
    'nature', 'animals', 'community', 'making', 'music', 'gathering',
    'adventure', 'discovery', 'play', 'learning', 'calm', 'milestones'
  )),
  constraint artwork_catalog_palette_check check (cardinality(dominant_colors) between 3 and 6),
  constraint artwork_catalog_dimensions_check check (source_width > 0 and source_height > 0),
  constraint artwork_catalog_crop_check check (
    crop_x >= 0 and crop_y >= 0 and crop_width > 0 and crop_height > 0
    and crop_x + crop_width <= 1 and crop_y + crop_height <= 1
    and abs((crop_width * source_width) - (crop_height * source_height)) < 2
  ),
  constraint artwork_catalog_revision_check check (catalog_revision > 0),
  constraint artwork_catalog_checksum_check check (manifest_checksum ~ '^[0-9a-f]{64}$')
);

alter table public.artwork_catalog enable row level security;
revoke all on table public.artwork_catalog from public, anon, authenticated;
grant all on table public.artwork_catalog to service_role;

create table public.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  rollout_percent integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint feature_flags_rollout_check check (rollout_percent between 0 and 100)
);

alter table public.feature_flags enable row level security;
create policy "authenticated users read feature flags"
  on public.feature_flags for select to authenticated using (true);
revoke all on table public.feature_flags from public, anon, authenticated;
grant select on table public.feature_flags to authenticated;
grant all on table public.feature_flags to service_role;

insert into public.feature_flags (key, enabled, rollout_percent)
values ('museum_art_creation', false, 0)
on conflict (key) do nothing;

create table private.artwork_assets (
  artwork_id uuid primary key references public.artwork_catalog(id) on delete cascade,
  display_path text not null unique,
  display_checksum text not null,
  display_byte_count bigint not null,
  export_path text not null unique,
  export_checksum text not null,
  export_byte_count bigint not null,
  provenance jsonb not null,
  imported_at timestamptz not null default now(),
  constraint artwork_assets_paths_check check (
    display_path ~ '^[0-9]+/843\.jpg$' and export_path ~ '^[0-9]+/1686\.jpg$'
  ),
  constraint artwork_assets_checksums_check check (
    display_checksum ~ '^[0-9a-f]{64}$' and export_checksum ~ '^[0-9a-f]{64}$'
  ),
  constraint artwork_assets_byte_count_check check (display_byte_count > 0 and export_byte_count > 0)
);

create table private.challenge_artwork_assignments (
  challenge_id uuid primary key references public.challenges(id) on delete cascade,
  artwork_id uuid not null references public.artwork_catalog(id) on delete restrict,
  catalog_revision integer not null,
  assigned_at timestamptz not null default now(),
  constraint challenge_assignment_revision_check check (catalog_revision > 0)
);

create table private.challenge_artwork_packages (
  challenge_id uuid primary key references private.challenge_artwork_assignments(challenge_id) on delete cascade,
  package_revision integer not null,
  storage_path text not null unique,
  key_base64 text not null,
  nonce_base64 text not null,
  aad text not null,
  checksum text not null,
  byte_count bigint not null,
  created_at timestamptz not null default now(),
  constraint challenge_package_revision_check check (package_revision > 0),
  constraint challenge_package_path_check check (storage_path ~ '^[0-9a-f-]{36}/[0-9]+\.aesgcm$'),
  constraint challenge_package_key_check check (char_length(key_base64) between 43 and 44),
  constraint challenge_package_nonce_check check (char_length(nonce_base64) = 16),
  constraint challenge_package_checksum_check check (checksum ~ '^[0-9a-f]{64}$'),
  constraint challenge_package_byte_count_check check (byte_count > 16)
);

alter table private.artwork_assets enable row level security;
alter table private.challenge_artwork_assignments enable row level security;
alter table private.challenge_artwork_packages enable row level security;
revoke all on table private.artwork_assets, private.challenge_artwork_assignments,
  private.challenge_artwork_packages from public, anon, authenticated;
grant usage on schema private to service_role;
grant all on table private.artwork_assets, private.challenge_artwork_assignments,
  private.challenge_artwork_packages to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('museum-artwork-sources', 'museum-artwork-sources', false, 20971520, array['image/jpeg']),
  ('museum-reveal-packages', 'museum-reveal-packages', false, 20971520, array['application/octet-stream'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create function public.internal_record_artwork_asset(
  target_artwork_id uuid,
  target_display_path text,
  target_display_checksum text,
  target_display_byte_count bigint,
  target_export_path text,
  target_export_checksum text,
  target_export_byte_count bigint,
  target_provenance jsonb
)
returns void
language sql
security invoker
set search_path = ''
as $$
  insert into private.artwork_assets (
    artwork_id, display_path, display_checksum, display_byte_count,
    export_path, export_checksum, export_byte_count, provenance, imported_at
  ) values (
    target_artwork_id, target_display_path, target_display_checksum, target_display_byte_count,
    target_export_path, target_export_checksum, target_export_byte_count, target_provenance, now()
  )
  on conflict (artwork_id) do update set
    display_path = excluded.display_path,
    display_checksum = excluded.display_checksum,
    display_byte_count = excluded.display_byte_count,
    export_path = excluded.export_path,
    export_checksum = excluded.export_checksum,
    export_byte_count = excluded.export_byte_count,
    provenance = excluded.provenance,
    imported_at = excluded.imported_at;
$$;

create function public.internal_get_artwork_asset(target_artwork_id uuid)
returns jsonb
language sql
security invoker
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'displayPath', asset.display_path,
    'displayChecksum', asset.display_checksum,
    'exportPath', asset.export_path,
    'exportChecksum', asset.export_checksum
  )
  from private.artwork_assets asset
  where asset.artwork_id = target_artwork_id;
$$;

revoke all on function public.internal_record_artwork_asset(uuid,text,text,bigint,text,text,bigint,jsonb) from public, anon, authenticated;
revoke all on function public.internal_get_artwork_asset(uuid) from public, anon, authenticated;
grant execute on function public.internal_record_artwork_asset(uuid,text,text,bigint,text,text,bigint,jsonb) to service_role;
grant execute on function public.internal_get_artwork_asset(uuid) to service_role;

create function public.internal_commit_museum_challenge(
  target_challenge_id uuid,
  target_artwork_id uuid,
  target_board_side integer,
  target_name text,
  target_group_name text,
  target_purpose text,
  target_start_at timestamptz,
  target_reveal_at timestamptz,
  target_package_revision integer,
  target_package_path text,
  target_key_base64 text,
  target_nonce_base64 text,
  target_aad text,
  target_checksum text,
  target_byte_count bigint
)
returns public.challenges
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.challenges;
  artwork public.artwork_catalog;
  current_assignment private.challenge_artwork_assignments;
  accepted_count integer;
begin
  if target_board_side < 3 or target_board_side > 10 then
    raise exception 'boardSide must be between 3 and 10';
  end if;

  select * into target from public.challenges where id = target_challenge_id for update;
  if not found then raise exception 'challenge not found'; end if;
  select * into artwork from public.artwork_catalog
    where id = target_artwork_id and active and is_public_domain;
  if not found then raise exception 'artwork not found'; end if;
  select * into current_assignment from private.challenge_artwork_assignments
    where challenge_id = target_challenge_id;
  select count(*) into accepted_count from public.contributions
    where challenge_id = target_challenge_id
      and status in ('self_attested', 'verified', 'placed', 'revealed');

  if accepted_count > 0 and (
    current_assignment.challenge_id is null
    or current_assignment.artwork_id <> target_artwork_id
    or target.board_side is distinct from target_board_side
  ) then
    raise exception 'Artwork and board dimensions are locked after the first accepted tile';
  end if;

  insert into private.challenge_artwork_assignments (
    challenge_id, artwork_id, catalog_revision, assigned_at
  ) values (
    target_challenge_id, target_artwork_id, artwork.catalog_revision, now()
  ) on conflict (challenge_id) do update set
    artwork_id = excluded.artwork_id,
    catalog_revision = excluded.catalog_revision,
    assigned_at = excluded.assigned_at;

  insert into private.challenge_artwork_packages (
    challenge_id, package_revision, storage_path, key_base64, nonce_base64,
    aad, checksum, byte_count, created_at
  ) values (
    target_challenge_id, target_package_revision, target_package_path, target_key_base64,
    target_nonce_base64, target_aad, target_checksum, target_byte_count, now()
  ) on conflict (challenge_id) do update set
    package_revision = excluded.package_revision,
    storage_path = excluded.storage_path,
    key_base64 = excluded.key_base64,
    nonce_base64 = excluded.nonce_base64,
    aad = excluded.aad,
    checksum = excluded.checksum,
    byte_count = excluded.byte_count,
    created_at = excluded.created_at;

  update public.challenges set
    name = target_name,
    group_name = target_group_name,
    purpose = target_purpose,
    goal = target_board_side * target_board_side,
    start_at = target_start_at,
    reveal_at = target_reveal_at,
    artwork_mode = 'museum',
    board_side = target_board_side,
    artwork_collection = artwork.collection,
    artwork_palette = artwork.dominant_colors,
    artwork_catalog_revision = artwork.catalog_revision,
    artwork_package_revision = target_package_revision,
    artwork_locked_at = now(),
    schedule_revision = schedule_revision + 1,
    updated_at = now()
  where id = target_challenge_id
  returning * into target;

  return target;
end;
$$;

revoke all on function public.internal_commit_museum_challenge(uuid,uuid,integer,text,text,text,timestamptz,timestamptz,integer,text,text,text,text,text,bigint) from public, anon, authenticated;
grant execute on function public.internal_commit_museum_challenge(uuid,uuid,integer,text,text,text,timestamptz,timestamptz,integer,text,text,text,text,text,bigint) to service_role;

create function public.internal_prefetch_reveal_package(target_challenge_id uuid, target_user_id uuid)
returns jsonb
language plpgsql
security invoker
stable
set search_path = ''
as $$
declare
  package private.challenge_artwork_packages;
begin
  if not exists (
    select 1 from public.challenge_members member
    where member.challenge_id = target_challenge_id and member.user_id = target_user_id
  ) then raise exception 'Challenge membership required'; end if;
  select * into package from private.challenge_artwork_packages where challenge_id = target_challenge_id;
  if not found then raise exception 'Reveal package is not ready'; end if;
  return jsonb_build_object(
    'storagePath', package.storage_path,
    'packageRevision', package.package_revision,
    'checksum', package.checksum,
    'byteCount', package.byte_count
  );
end;
$$;

create function public.internal_release_reveal_package(target_challenge_id uuid, target_user_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.challenges;
  package private.challenge_artwork_packages;
  assignment private.challenge_artwork_assignments;
  artwork public.artwork_catalog;
  asset private.artwork_assets;
begin
  if not exists (
    select 1 from public.challenge_members member
    where member.challenge_id = target_challenge_id and member.user_id = target_user_id
  ) then raise exception 'Challenge membership required'; end if;

  select * into target from public.challenges where id = target_challenge_id for update;
  if not found or target.artwork_mode <> 'museum' then raise exception 'Museum artwork challenge required'; end if;

  if target.status = 'awaiting_reveal' and target.reveal_at <= now() then
    update public.challenges set
      status = 'revealed', revealed_at = coalesce(revealed_at, now()), updated_at = now()
    where id = target_challenge_id
    returning * into target;
    update public.contributions set status = 'revealed', updated_at = now()
    where challenge_id = target_challenge_id and status = 'placed';
  end if;

  if target.status <> 'revealed' then raise exception 'Artwork key is not available before reveal'; end if;

  select * into package from private.challenge_artwork_packages where challenge_id = target_challenge_id;
  select * into assignment from private.challenge_artwork_assignments where challenge_id = target_challenge_id;
  select * into artwork from public.artwork_catalog where id = assignment.artwork_id;
  select * into asset from private.artwork_assets where artwork_id = assignment.artwork_id;
  if package.challenge_id is null or artwork.id is null or asset.artwork_id is null then
    raise exception 'Reveal package is incomplete';
  end if;

  return jsonb_build_object(
    'packageRevision', package.package_revision,
    'checksum', package.checksum,
    'key', package.key_base64,
    'nonce', package.nonce_base64,
    'aad', package.aad,
    'exportPath', asset.export_path,
    'exportChecksum', asset.export_checksum,
    'artwork', jsonb_build_object(
      'id', artwork.id,
      'museumArtworkId', artwork.museum_artwork_id,
      'title', artwork.title,
      'artistDisplay', artwork.artist_display,
      'dateDisplay', artwork.date_display,
      'sourceURL', artwork.source_url,
      'altText', artwork.alt_text,
      'licenseLabel', artwork.license_label,
      'crop', jsonb_build_object(
        'x', artwork.crop_x, 'y', artwork.crop_y,
        'width', artwork.crop_width, 'height', artwork.crop_height
      )
    )
  );
end;
$$;

revoke all on function public.internal_prefetch_reveal_package(uuid,uuid) from public, anon, authenticated;
revoke all on function public.internal_release_reveal_package(uuid,uuid) from public, anon, authenticated;
grant execute on function public.internal_prefetch_reveal_package(uuid,uuid) to service_role;
grant execute on function public.internal_release_reveal_package(uuid,uuid) to service_role;

create or replace function public.internal_place_tile(target_contribution_id uuid, target_user_id uuid)
returns public.contributions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target public.contributions;
  challenge public.challenges;
  next_position integer;
  placed_count integer;
begin
  select contribution.* into target
  from public.contributions contribution
  join public.contribution_owners owner on owner.contribution_id = contribution.id
  where contribution.id = target_contribution_id and owner.participant_id = target_user_id;

  if not found then raise exception 'contribution not owned by caller'; end if;
  if target.status = 'placed' or target.status = 'revealed' then return target; end if;
  if target.status not in ('self_attested', 'verified') then
    raise exception 'contribution is not ready for placement';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(target.challenge_id::text, 0));
  select * into challenge from public.challenges where id = target.challenge_id for update;
  if challenge.status <> 'active' then raise exception 'challenge is closed for contributions'; end if;

  select count(*) into placed_count from public.contributions contribution
    where contribution.challenge_id = target.challenge_id and contribution.tile_position is not null;
  if placed_count >= challenge.goal then raise exception 'challenge has reached its tile capacity'; end if;

  select slot into next_position
  from generate_series(0, challenge.goal - 1) slot
  where not exists (
    select 1 from public.contributions contribution
    where contribution.challenge_id = target.challenge_id and contribution.tile_position = slot
  )
  order by slot limit 1;

  update public.contributions set
    status = 'placed', tile_position = next_position, updated_at = now()
  where id = target_contribution_id
  returning * into target;

  if challenge.artwork_mode = 'museum' and placed_count + 1 = challenge.goal then
    update public.challenges set status = 'awaiting_reveal', updated_at = now()
    where id = challenge.id and status = 'active';
  end if;
  return target;
end;
$$;

revoke all on function public.internal_place_tile(uuid, uuid) from public, anon, authenticated;
grant execute on function public.internal_place_tile(uuid, uuid) to service_role;

create or replace function private.activate_due_reveals()
returns void
language sql
security definer
set search_path = ''
as $$
  with due as (
    update public.challenges
    set status = 'revealed', revealed_at = coalesce(revealed_at, now()), updated_at = now()
    where reveal_at <= now()
      and (
        (artwork_mode = 'museum' and status = 'awaiting_reveal')
        or (artwork_mode = 'legacy' and status = 'active')
      )
    returning id
  )
  update public.contributions contribution
  set status = 'revealed', updated_at = now()
  where contribution.status = 'placed'
    and contribution.challenge_id in (select id from due);
$$;

revoke all on function private.activate_due_reveals() from public, anon, authenticated;
