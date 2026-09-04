-- Additive v2 shared-kindness-roll contract. Legacy challenges and rows remain valid.
alter table public.challenges
  add column experience_version integer not null default 1,
  add column film_look_id text not null default 'sunwashed';

alter table public.challenges
  add constraint challenges_experience_version check (experience_version in (1, 2)),
  add constraint challenges_film_look check (film_look_id in ('sunwashed', 'garden', 'afterglow'));

create or replace function private.guard_kindness_roll_identity()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (
    select 1 from public.contributions c
    where c.challenge_id = old.id
      and c.status in ('self_attested','verified','placed','revealed')
  ) and (
    old.experience_version is distinct from new.experience_version
    or old.film_look_id is distinct from new.film_look_id
  ) then
    raise exception 'experience and film look are locked after the first sealed contribution';
  end if;
  return new;
end;
$$;

create trigger guard_kindness_roll_identity
before update of experience_version, film_look_id on public.challenges
for each row execute function private.guard_kindness_roll_identity();

drop policy "members can read safe contribution tiles" on public.contributions;
create policy "members can read safe contribution tiles"
on public.contributions for select to authenticated using (
  private.is_challenge_member(challenge_id) and exists (
    select 1 from public.challenges challenge
    where challenge.id = challenge_id and (
      challenge.experience_version = 1
      or challenge.status = 'revealed'
      or private.is_challenge_organizer(challenge_id)
      or private.owns_contribution(contributions.id)
    )
  )
);

create or replace function private.refresh_shared_roll_count()
returns trigger language plpgsql security definer set search_path = '' as $$
declare target uuid := coalesce(new.challenge_id, old.challenge_id);
begin
  insert into public.shared_roll_counts(challenge_id, sealed_count, approved_count, updated_at)
  select target,
    count(*) filter (where lifecycle in ('upload_pending','sealed_pending_review','sealed','approved')),
    count(*) filter (where lifecycle in ('sealed','approved') and reveal_consent and deleted_at is null and reported_at is null), now()
  from public.shared_moments where challenge_id = target
  on conflict (challenge_id) do update set sealed_count = excluded.sealed_count,
    approved_count = excluded.approved_count, updated_at = excluded.updated_at;
  return coalesce(new, old);
end;
$$;

alter table public.shared_moments
  add column contribution_id uuid references public.contributions(id) on delete cascade,
  add column film_look_id text;

alter table public.shared_moments
  add constraint shared_moments_film_look check (
    film_look_id is null or film_look_id in ('sunwashed', 'garden', 'afterglow')
  );

create unique index shared_moments_contribution_unique
  on public.shared_moments(contribution_id)
  where contribution_id is not null;

alter table public.shared_moments drop constraint shared_moments_lifecycle;
alter table public.shared_moments add constraint shared_moments_lifecycle check (
  lifecycle in (
    'local_draft','upload_pending','sealed_pending_review','sealed','approved',
    'rejected','deleted','reported','consent_revoked'
  )
);

drop policy "owners organizers and revealed members read shared moments" on public.shared_moments;
create policy "owners organizers and revealed members read shared moments"
on public.shared_moments for select to authenticated using (
  creator_id = (select auth.uid())
  or private.is_challenge_organizer(challenge_id)
  or (
    private.is_challenge_member(challenge_id)
    and lifecycle in ('sealed','approved') and reveal_consent
    and deleted_at is null and reported_at is null
    and exists (
      select 1 from public.challenges c
      where c.id = challenge_id and c.status = 'revealed'
    )
  )
);

create or replace function private.guard_shared_moment_update()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.creator_id <> new.creator_id or old.challenge_id <> new.challenge_id
     or old.created_at <> new.created_at or old.contribution_id is distinct from new.contribution_id then
    raise exception 'immutable shared moment ownership';
  end if;
  if not private.is_challenge_organizer(old.challenge_id) then
    if new.lifecycle not in ('upload_pending','sealed_pending_review','sealed','approved','deleted','consent_revoked') then
      raise exception 'invalid owner lifecycle transition';
    end if;
    if new.lifecycle = 'approved' and old.lifecycle <> 'approved' then
      raise exception 'only organizers approve shared moments';
    end if;
    if new.lifecycle = 'sealed' and old.lifecycle <> 'sealed'
       and coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
      raise exception 'only the server can develop shared moments';
    end if;
    if old.reported_at is distinct from new.reported_at then
      raise exception 'reported state is server managed';
    end if;
    new.consent_version := old.consent_version + case
      when old.reveal_consent is distinct from new.reveal_consent
        or old.export_consent is distinct from new.export_consent then 1 else 0 end;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

-- The Edge Function prepares uploads, then calls this internal routine once the
-- private object exists. Assignment and state transition stay atomic.
create or replace function public.internal_finalize_kindness_roll_contribution(
  target_contribution_id uuid,
  target_moment_id uuid,
  target_user_id uuid
)
returns table(contribution_id uuid, tile_position integer, moment_id uuid)
language plpgsql security definer set search_path = '' as $$
declare
  target_challenge_id uuid;
  contribution_status public.contribution_status;
  existing_position integer;
  challenge_status text;
  challenge_reveal_at timestamptz;
  next_position integer;
begin
  select c.challenge_id, c.status, c.tile_position, challenge.status, challenge.reveal_at
  into target_challenge_id, contribution_status, existing_position, challenge_status, challenge_reveal_at
  from public.contributions c
  join public.contribution_owners co on co.contribution_id = c.id
  join public.challenges challenge on challenge.id = c.challenge_id
  where c.id = target_contribution_id
    and co.participant_id = target_user_id
    and challenge.experience_version = 2
  for update of c;

  if target_challenge_id is null then
    raise exception 'contribution is not ready or the roll is closed';
  end if;

  if contribution_status in ('placed','revealed') and existing_position is not null and exists (
    select 1 from public.shared_moments sm
    where sm.id = target_moment_id and sm.contribution_id = target_contribution_id
      and sm.creator_id = target_user_id and sm.lifecycle in ('sealed','approved')
  ) then
    return query select target_contribution_id, existing_position, target_moment_id;
    return;
  end if;

  if contribution_status <> 'draft' or challenge_status <> 'active' or challenge_reveal_at <= now() then
    raise exception 'contribution is not ready or the roll is closed';
  end if;

  if not exists (
    select 1 from public.shared_moments sm
    where sm.id = target_moment_id
      and sm.contribution_id = target_contribution_id
      and sm.creator_id = target_user_id
      and sm.lifecycle = 'upload_pending'
  ) then
    raise exception 'sealed moment is missing';
  end if;

  select slot into next_position
  from generate_series(
    0,
    (select goal - 1 from public.challenges where id = target_challenge_id)
  ) as slot
  where not exists (
    select 1 from public.contributions occupied
    where occupied.challenge_id = target_challenge_id
      and occupied.tile_position = slot
      and occupied.status in ('self_attested','verified','placed','revealed')
  )
  order by slot
  limit 1;

  if next_position is null then raise exception 'kindness roll is full'; end if;

  update public.contributions
  set status = 'placed', verification_level = 'self_attested',
      tile_position = next_position, updated_at = now()
  where id = target_contribution_id;

  update public.shared_moments
  set lifecycle = 'sealed', updated_at = now()
  where id = target_moment_id;

  return query select target_contribution_id, next_position, target_moment_id;
end;
$$;

revoke all on function public.internal_finalize_kindness_roll_contribution(uuid, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.internal_finalize_kindness_roll_contribution(uuid, uuid, uuid)
  to service_role;

create or replace function public.internal_withdraw_kindness_roll_moment(
  target_moment_id uuid,
  target_user_id uuid
)
returns table(action text, media_path text)
language plpgsql security definer set search_path = '' as $$
declare
  target_contribution_id uuid;
  target_challenge_id uuid;
  target_media_path text;
  already_revealed boolean;
begin
  select sm.contribution_id, sm.challenge_id, sm.media_path,
    (challenge.status = 'revealed' or challenge.reveal_at <= now())
  into target_contribution_id, target_challenge_id, target_media_path, already_revealed
  from public.shared_moments sm
  join public.challenges challenge on challenge.id = sm.challenge_id
  where sm.id = target_moment_id and sm.creator_id = target_user_id
  for update of sm;

  if target_challenge_id is null then raise exception 'moment not found'; end if;

  if already_revealed then
    update public.shared_moments
    set lifecycle = 'consent_revoked', reveal_consent = false,
        export_consent = false, deleted_at = now(), updated_at = now()
    where id = target_moment_id;
    return query select 'revoked'::text, target_media_path;
  else
    update public.shared_moments
    set lifecycle = 'deleted', reveal_consent = false,
        export_consent = false, deleted_at = now(), updated_at = now()
    where id = target_moment_id;
    update public.contributions
    set status = 'archived', tile_position = null, updated_at = now()
    where id = target_contribution_id;
    return query select 'withdrawn'::text, target_media_path;
  end if;
end;
$$;

revoke all on function public.internal_withdraw_kindness_roll_moment(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.internal_withdraw_kindness_roll_moment(uuid, uuid)
  to service_role;

create or replace view public.recap_sources with (security_invoker = true) as
select m.id, 'contribution'::text as origin, m.contribution_id, c.challenge_id, co.participant_id,
  case when m.show_identity then nullif(cm.display_name, '') else null end as participant_display_name,
  m.show_identity as attribution_allowed, mission.category, coalesce(m.approved_at, c.updated_at) as accepted_at,
  m.media_path, m.story_text, c.emotion::text as emotion, c.tile_position, false as is_revived,
  m.media_version, m.consent_version, (c.status in ('verified','placed','revealed')) as accepted,
  m.export_consent as recap_consent, (m.media_path is not null or m.story_text is not null) as media_exists,
  (m.deleted_at is not null) as is_deleted, (m.reported_at is not null) as is_reported,
  exists (select 1 from public.user_blocks ub where ub.blocker_id = (select auth.uid()) and ub.blocked_id = co.participant_id) as contributor_is_blocked,
  case when m.media_path is null then 'note' when right(lower(m.media_path), 4) in ('.mov', '.mp4') then 'video' else 'photo' end::text as media_kind,
  case when m.media_path is null then null when right(lower(m.media_path), 4) = '.mov' then 'video/quicktime'
       when right(lower(m.media_path), 4) = '.mp4' then 'video/mp4'
       when right(lower(m.media_path), 4) = '.png' then 'image/png' else 'image/jpeg' end::text as media_mime_type,
  null::numeric as duration_seconds
from public.memories m
join public.contributions c on c.id = m.contribution_id
join public.contribution_owners co on co.contribution_id = c.id
join public.missions mission on mission.id = c.mission_id
left join public.challenge_members cm on cm.challenge_id = c.challenge_id and cm.user_id = co.participant_id
join public.challenges challenge on challenge.id = c.challenge_id
where challenge.status = 'revealed' and m.review_status = 'approved' and m.export_consent
  and m.deleted_at is null and m.reported_at is null
  and not exists (select 1 from public.shared_moments sm where sm.contribution_id = m.contribution_id)
  and not exists (select 1 from public.user_blocks ub where ub.blocker_id = (select auth.uid()) and ub.blocked_id = co.participant_id)
union all
select sm.id, 'shared_moment'::text, sm.contribution_id, sm.challenge_id, sm.creator_id,
  case when sm.attribution = 'permitted' then nullif(cm.display_name, '') else null end,
  sm.attribution = 'permitted', sm.editorial_category, sm.created_at, sm.media_path, sm.note,
  c.emotion::text, c.tile_position, false, sm.media_version, sm.consent_version,
  c.status in ('placed','revealed'), sm.export_consent,
  (sm.media_path is not null or sm.note is not null), sm.deleted_at is not null, sm.reported_at is not null,
  exists (select 1 from public.user_blocks ub where ub.blocker_id = (select auth.uid()) and ub.blocked_id = sm.creator_id),
  sm.media_kind, sm.media_mime_type, sm.duration_seconds
from public.shared_moments sm
join public.challenges challenge on challenge.id = sm.challenge_id
left join public.contributions c on c.id = sm.contribution_id
left join public.challenge_members cm on cm.challenge_id = sm.challenge_id and cm.user_id = sm.creator_id
where challenge.status = 'revealed' and sm.lifecycle in ('sealed','approved')
  and sm.reveal_consent and sm.export_consent
  and sm.deleted_at is null and sm.reported_at is null
  and not exists (select 1 from public.user_blocks ub where ub.blocker_id = (select auth.uid()) and ub.blocked_id = sm.creator_id);

revoke all on public.recap_sources from public, anon, authenticated;
grant select on public.recap_sources to authenticated;

drop policy "authorized members read revealed moments" on storage.objects;
create policy "authorized members read revealed moments"
on storage.objects for select to authenticated using (
  bucket_id = 'recap-memories' and exists (
    select 1 from public.shared_moments sm
    join public.challenges c on c.id = sm.challenge_id
    where sm.media_path = name and (
      sm.creator_id = (select auth.uid())
      or private.is_challenge_organizer(sm.challenge_id)
      or (private.is_challenge_member(sm.challenge_id) and c.status = 'revealed'
          and sm.lifecycle in ('sealed','approved') and sm.reveal_consent)
    )
  )
);
