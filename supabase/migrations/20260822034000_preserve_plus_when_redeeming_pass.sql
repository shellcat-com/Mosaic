-- A PASS is durable fallback access, but it must never downgrade an active
-- Organizer Plus workspace from its higher participant/collaborator limits.

create or replace function public.internal_record_event_pass(
  target_organization_id uuid,
  target_challenge_id uuid,
  target_owner_id uuid,
  target_transaction_id text
)
returns public.challenge_access_grants
language plpgsql security definer set search_path = '' as $$
declare
  result public.challenge_access_grants;
  plus_active boolean;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(target_challenge_id::text, 0));
  if not exists (
    select 1 from public.organization_members
    where organization_id = target_organization_id and user_id = target_owner_id and role = 'owner'
  ) then raise exception 'organization ownership required'; end if;
  if not exists (
    select 1 from public.challenges
    where id = target_challenge_id and organization_id = target_organization_id
  ) then raise exception 'challenge does not belong to organization'; end if;
  if exists (select 1 from public.challenge_access_grants where challenge_id = target_challenge_id and revoked_at is null)
  then raise exception 'challenge already has premium access'; end if;
  update public.billing_accounts set pass_balance = pass_balance - 1, updated_at = now()
    where organization_id = target_organization_id and pass_balance > 0;
  if not found then raise exception 'no PASS balance available'; end if;
  insert into public.challenge_access_grants(
    challenge_id, organization_id, source, revenuecat_transaction_id, granted_by
  ) values (
    target_challenge_id, target_organization_id, 'event_pass', target_transaction_id, target_owner_id
  ) returning * into result;
  plus_active := private.has_current_plus(target_organization_id, now());
  update public.challenges set
    access_source = case when plus_active then 'organizer_plus'::public.challenge_access_source else 'event_pass'::public.challenge_access_source end,
    participant_limit = case when plus_active then 250 else 100 end,
    collaborator_limit = case when plus_active then 5 else 2 end
  where id = target_challenge_id;
  return result;
end;
$$;

create or replace function public.internal_complete_event_pass_redemption(
  target_challenge_id uuid,
  target_transaction_id text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  redemption public.pass_redemptions;
  result public.challenge_access_grants;
  plus_active boolean;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(target_challenge_id::text, 0));
  select * into redemption from public.pass_redemptions
    where challenge_id = target_challenge_id for update;
  if not found then raise exception 'PASS redemption reservation required'; end if;
  if redemption.status = 'completed' then
    select * into result from public.challenge_access_grants
      where challenge_id = target_challenge_id and revoked_at is null limit 1;
    return jsonb_build_object('grant', to_jsonb(result), 'already_completed', true);
  end if;

  insert into public.challenge_access_grants(
    challenge_id, organization_id, source, revenuecat_transaction_id, granted_by
  ) values (
    redemption.challenge_id, redemption.organization_id, 'event_pass',
    target_transaction_id, redemption.owner_user_id
  ) returning * into result;
  update public.billing_accounts
    set pass_balance = greatest(pass_balance - 1, 0), updated_at = now()
    where organization_id = redemption.organization_id;
  plus_active := private.has_current_plus(redemption.organization_id, now());
  update public.challenges set
    access_source = case when plus_active then 'organizer_plus'::public.challenge_access_source else 'event_pass'::public.challenge_access_source end,
    participant_limit = case when plus_active then 250 else 100 end,
    collaborator_limit = case when plus_active then 5 else 2 end
  where id = redemption.challenge_id;
  update public.pass_redemptions
    set status = 'completed', revenuecat_transaction_id = target_transaction_id,
        completed_at = now(), updated_at = now()
    where challenge_id = redemption.challenge_id;
  return jsonb_build_object('grant', to_jsonb(result), 'already_completed', false);
end;
$$;

-- Repair any active Plus challenge that was reduced by an earlier PASS
-- redemption while retaining the PASS grant as durable fallback access.
update public.challenges c
set access_source = 'organizer_plus', participant_limit = 250, collaborator_limit = 5
where private.has_current_plus(c.organization_id, now())
  and exists (
    select 1 from public.challenge_access_grants grant_row
    where grant_row.challenge_id = c.id
      and grant_row.source = 'event_pass'
      and grant_row.revoked_at is null
      and (grant_row.valid_until is null or grant_row.valid_until > now())
  );
