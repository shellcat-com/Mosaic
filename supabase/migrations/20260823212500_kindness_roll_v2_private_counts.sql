-- Version-2 members see aggregate progress and their own sealed metadata before
-- reveal. Legacy contribution visibility remains unchanged.
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
