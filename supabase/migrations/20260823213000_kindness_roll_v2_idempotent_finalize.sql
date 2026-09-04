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
