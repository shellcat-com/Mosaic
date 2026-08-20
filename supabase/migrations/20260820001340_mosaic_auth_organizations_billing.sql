-- Mosaic workspaces and RevenueCat-derived access. All writes to these tables
-- happen through authenticated Edge Functions or the RevenueCat webhook.
create type public.organization_role as enum ('owner', 'admin', 'reviewer');
create type public.challenge_access_source as enum ('free', 'organizer_plus', 'event_pass');
create type public.billing_subscription_status as enum (
  'none', 'trialing', 'active', 'grace_period', 'billing_issue', 'cancelled', 'expired'
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organizations_name_length check (char_length(name) between 1 and 100)
);

create table public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.organization_role not null,
  joined_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);
create index organization_members_user_idx
  on public.organization_members(user_id, organization_id);
create unique index one_owner_per_organization
  on public.organization_members(organization_id) where role = 'owner';

create table public.organization_invites (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  role public.organization_role not null,
  token_hash text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint organization_invites_non_owner check (role in ('admin', 'reviewer')),
  constraint organization_invites_valid_expiry check (expires_at > created_at),
  constraint organization_invites_acceptance_complete check (
    (accepted_at is null and accepted_by is null) or
    (accepted_at is not null and accepted_by is not null)
  )
);
create index organization_invites_active_idx
  on public.organization_invites(organization_id, expires_at)
  where accepted_at is null and revoked_at is null;

create table public.billing_accounts (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  revenuecat_customer_id text not null unique,
  entitlement_id text not null default 'organizer_plus',
  subscription_status public.billing_subscription_status not null default 'none',
  product_id text,
  entitlement_expires_at timestamptz,
  will_renew boolean not null default false,
  pass_balance integer not null default 0,
  last_event_at timestamptz,
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint billing_accounts_customer_length check (char_length(revenuecat_customer_id) between 1 and 200),
  constraint billing_accounts_pass_nonnegative check (pass_balance >= 0)
);

create table public.billing_events (
  event_id text primary key,
  event_type text not null,
  revenuecat_customer_id text,
  product_id text,
  transaction_id text,
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  payload_sha256 text not null,
  processing_error text,
  constraint billing_events_id_length check (char_length(event_id) between 1 and 200),
  constraint billing_events_type_length check (char_length(event_type) between 1 and 100),
  constraint billing_events_error_length check (processing_error is null or char_length(processing_error) <= 500)
);
create index billing_events_customer_idx
  on public.billing_events(revenuecat_customer_id, occurred_at desc);

drop index if exists public.one_sandbox_per_organizer;

alter table public.challenges
  add column organization_id uuid references public.organizations(id) on delete cascade,
  add column created_by uuid references auth.users(id) on delete restrict,
  add column access_source public.challenge_access_source not null default 'free',
  add column premium_access_until timestamptz,
  add column participant_limit integer not null default 25,
  add column collaborator_limit integer not null default 0,
  add column custom_artwork_enabled boolean not null default false,
  add constraint challenges_duration_limit check (reveal_at <= start_at + interval '90 days'),
  add constraint challenges_participant_limit check (participant_limit between 1 and 250),
  add constraint challenges_collaborator_limit check (collaborator_limit between 0 and 5),
  add constraint challenges_workspace_required check (
    is_showcase or (organization_id is not null and created_by is not null)
  );
create index challenges_organization_idx
  on public.challenges(organization_id, status, reveal_at);

-- Preserve existing organizer-owned demo data by assigning each organizer a
-- default workspace. Showcase challenges deliberately remain organization-free.
insert into public.organizations (id, name, created_by)
select (substr(md5('mosaic-organization:' || c.organizer_id::text), 1, 8) || '-' ||
        substr(md5('mosaic-organization:' || c.organizer_id::text), 9, 4) || '-4' ||
        substr(md5('mosaic-organization:' || c.organizer_id::text), 14, 3) || '-8' ||
        substr(md5('mosaic-organization:' || c.organizer_id::text), 18, 3) || '-' ||
        substr(md5('mosaic-organization:' || c.organizer_id::text), 21, 12))::uuid,
       coalesce(nullif(p.display_name, ''), 'Mosaic') || '''s workspace',
       c.organizer_id
from public.challenges c
left join public.profiles p on p.user_id = c.organizer_id
where c.organizer_id is not null and not c.is_showcase
group by c.organizer_id, p.display_name
on conflict (id) do nothing;

insert into public.organization_members (organization_id, user_id, role)
select o.id, o.created_by, 'owner'::public.organization_role
from public.organizations o
on conflict (organization_id, user_id) do nothing;

update public.challenges c
set organization_id = (substr(md5('mosaic-organization:' || c.organizer_id::text), 1, 8) || '-' ||
                       substr(md5('mosaic-organization:' || c.organizer_id::text), 9, 4) || '-4' ||
                       substr(md5('mosaic-organization:' || c.organizer_id::text), 14, 3) || '-8' ||
                       substr(md5('mosaic-organization:' || c.organizer_id::text), 18, 3) || '-' ||
                       substr(md5('mosaic-organization:' || c.organizer_id::text), 21, 12))::uuid,
    created_by = c.organizer_id
where c.organizer_id is not null and not c.is_showcase;

create table public.challenge_access_grants (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  source public.challenge_access_source not null,
  revenuecat_transaction_id text,
  granted_by uuid references auth.users(id) on delete set null,
  valid_until timestamptz,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint challenge_access_grants_paid_source check (source <> 'free'),
  constraint challenge_access_grants_workspace_match unique (challenge_id, source)
);
create unique index challenge_access_grants_transaction_idx
  on public.challenge_access_grants(revenuecat_transaction_id)
  where revenuecat_transaction_id is not null;

-- A durable redemption reservation closes the gap between the RevenueCat
-- virtual-currency debit and the database grant. Retries reuse the same
-- challenge-scoped idempotency key and finish the pending reservation.
create table public.pass_redemptions (
  challenge_id uuid primary key references public.challenges(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  operation_id uuid not null unique default gen_random_uuid(),
  status text not null default 'pending' check (status in ('pending', 'completed')),
  revenuecat_transaction_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create function private.is_anonymous_user()
returns boolean language sql stable set search_path = '' as $$
  select coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false);
$$;

create function private.organization_role_for(requested_organization_id uuid)
returns public.organization_role
language sql stable security definer set search_path = '' as $$
  select om.role from public.organization_members om
  where om.organization_id = requested_organization_id
    and om.user_id = (select auth.uid());
$$;

create function private.is_organization_member(requested_organization_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.organization_role_for(requested_organization_id) is not null;
$$;

create function private.can_manage_organization(requested_organization_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.organization_role_for(requested_organization_id) in ('owner', 'admin');
$$;

create function private.can_review_organization(requested_organization_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.organization_role_for(requested_organization_id) in ('owner', 'admin', 'reviewer');
$$;

create function private.has_current_plus(requested_organization_id uuid, at_time timestamptz default now())
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.billing_accounts ba
    where ba.organization_id = requested_organization_id
      -- Cancellation means auto-renew is off, not that paid access ended.
      -- Billing issues can also retain entitlement during Apple's grace window.
      and ba.subscription_status in ('trialing', 'active', 'grace_period', 'billing_issue', 'cancelled')
      and (ba.entitlement_expires_at is null or ba.entitlement_expires_at > at_time)
  );
$$;

create function private.has_challenge_premium_access(requested_challenge_id uuid, at_time timestamptz default now())
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.challenges c
    where c.id = requested_challenge_id and (
      private.has_current_plus(c.organization_id, at_time)
      or exists (
        select 1 from public.challenge_access_grants cag
        where cag.challenge_id = c.id and cag.revoked_at is null
          and (cag.valid_until is null or cag.valid_until > at_time)
      )
      or (c.access_source = 'organizer_plus' and c.premium_access_until > at_time)
    )
  );
$$;

-- A compact, server-derived snapshot for presentation. It deliberately never
-- trusts entitlement or PASS values supplied by the app.
create function public.organization_access_snapshot(
  requested_organization_id uuid,
  requested_challenge_id uuid default null
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  role_value public.organization_role;
  account public.billing_accounts;
  plus_active boolean;
  event_pass_active boolean;
begin
  if private.is_anonymous_user() then raise exception 'authenticated account required'; end if;
  role_value := private.organization_role_for(requested_organization_id);
  if role_value is null then raise exception 'organization membership required'; end if;
  select * into account from public.billing_accounts where organization_id = requested_organization_id;
  plus_active := private.has_current_plus(requested_organization_id, now());
  event_pass_active := requested_challenge_id is not null and exists (
    select 1
    from public.challenges c
    join public.challenge_access_grants grant_row on grant_row.challenge_id = c.id
    where c.id = requested_challenge_id
      and c.organization_id = requested_organization_id
      and grant_row.source = 'event_pass'
      and grant_row.revoked_at is null
      and (grant_row.valid_until is null or grant_row.valid_until > now())
  );
  return jsonb_build_object(
    'organization_id', requested_organization_id,
    'role', role_value,
    'plus_active', plus_active,
    'plus_expires_at', account.entitlement_expires_at,
    'will_renew', coalesce(account.will_renew, false),
    'subscription_status', coalesce(account.subscription_status::text, 'none'),
    'product_id', account.product_id,
    'pass_balance', coalesce(account.pass_balance, 0),
    'current_challenge_has_event_pass', event_pass_active,
    'active_challenge_limit', case when plus_active then 10 else 1 end,
    'participant_limit', case when plus_active then 250 when event_pass_active then 100 else 25 end,
    'collaborator_limit', case when plus_active then 5 when event_pass_active then 2 else 0 end
  );
end;
$$;

-- Called by the service-role Edge Function after a successful RevenueCat PASS
-- debit. Advisory locking plus the unique challenge grant prevents double spend.
create function public.internal_record_event_pass(
  target_organization_id uuid,
  target_challenge_id uuid,
  target_owner_id uuid,
  target_transaction_id text
)
returns public.challenge_access_grants
language plpgsql security definer set search_path = '' as $$
declare result public.challenge_access_grants;
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
  update public.challenges set access_source = 'event_pass', participant_limit = 100, collaborator_limit = 2
    where id = target_challenge_id;
  return result;
end;
$$;

create function public.internal_begin_event_pass_redemption(
  target_organization_id uuid,
  target_challenge_id uuid,
  target_owner_id uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  redemption public.pass_redemptions;
  existing_grant public.challenge_access_grants;
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

  select * into existing_grant from public.challenge_access_grants
    where challenge_id = target_challenge_id and revoked_at is null limit 1;
  if found then
    return jsonb_build_object(
      'status', 'completed', 'already_completed', true,
      'grant', to_jsonb(existing_grant)
    );
  end if;

  select * into redemption from public.pass_redemptions
    where challenge_id = target_challenge_id for update;
  if found then
    return jsonb_build_object(
      'status', redemption.status,
      'already_completed', redemption.status = 'completed',
      'operation_id', redemption.operation_id
    );
  end if;

  if not exists (
    select 1 from public.billing_accounts
    where organization_id = target_organization_id and pass_balance > 0
  ) then raise exception 'no PASS balance available'; end if;

  insert into public.pass_redemptions(challenge_id, organization_id, owner_user_id)
    values(target_challenge_id, target_organization_id, target_owner_id)
    returning * into redemption;
  return jsonb_build_object(
    'status', redemption.status,
    'already_completed', false,
    'operation_id', redemption.operation_id
  );
end;
$$;

create function public.internal_complete_event_pass_redemption(
  target_challenge_id uuid,
  target_transaction_id text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  redemption public.pass_redemptions;
  result public.challenge_access_grants;
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
  update public.challenges
    set access_source = 'event_pass', participant_limit = 100, collaborator_limit = 2
    where id = redemption.challenge_id;
  update public.pass_redemptions
    set status = 'completed', revenuecat_transaction_id = target_transaction_id,
        completed_at = now(), updated_at = now()
    where challenge_id = redemption.challenge_id;
  return jsonb_build_object('grant', to_jsonb(result), 'already_completed', false);
end;
$$;

create function public.internal_create_organization(
  owner_id uuid,
  organization_name text,
  organizer_display_name text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  new_organization public.organizations;
  new_challenge public.challenges;
  showcase_id uuid;
begin
  if char_length(trim(organization_name)) not between 1 and 100 then
    raise exception 'invalid organization name';
  end if;
  if char_length(trim(organizer_display_name)) not between 1 and 60 then
    raise exception 'invalid organizer display name';
  end if;
  insert into public.profiles(user_id, display_name, is_demo, updated_at)
    values(owner_id, trim(organizer_display_name), false, now())
    on conflict(user_id) do update set display_name = excluded.display_name, is_demo = false, updated_at = now();
  insert into public.organizations(name, created_by)
    values(trim(organization_name), owner_id) returning * into new_organization;
  insert into public.organization_members(organization_id, user_id, role)
    values(new_organization.id, owner_id, 'owner');
  insert into public.billing_accounts(organization_id, owner_user_id, revenuecat_customer_id)
    values(new_organization.id, owner_id, owner_id::text);
  insert into public.challenges(
    organizer_id, organization_id, created_by, name, group_name, purpose, goal,
    start_at, reveal_at, invitation_code, participant_limit
  ) values (
    owner_id, new_organization.id, owner_id, 'First Mosaic', trim(organization_name),
    'A welcoming first challenge for your community.', 25, now(), now() + interval '7 days',
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)), 25
  ) returning * into new_challenge;
  insert into public.challenge_members(challenge_id, user_id, role, display_name, privacy)
    values(new_challenge.id, owner_id, 'organizer', trim(organizer_display_name), 'first_name');
  select id into showcase_id from public.challenges where is_showcase limit 1;
  if showcase_id is not null then
    insert into public.missions(challenge_id, title, detail, category, minutes, effort, accepted_evidence, sort_order)
      select new_challenge.id, title, detail, category, minutes, effort, accepted_evidence, sort_order
      from public.missions where challenge_id = showcase_id order by sort_order;
  end if;
  return jsonb_build_object('organization', to_jsonb(new_organization), 'challenge', to_jsonb(new_challenge));
end;
$$;

create function public.internal_accept_organization_invite(
  accepting_user_id uuid,
  supplied_token_hash text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare target public.organization_invites;
declare organization_value public.organizations;
begin
  select * into target from public.organization_invites
    where token_hash = supplied_token_hash for update;
  if not found or target.revoked_at is not null or target.accepted_at is not null then
    raise exception 'invitation is invalid or already used';
  end if;
  if target.expires_at <= now() then raise exception 'invitation has expired'; end if;
  if target.role = 'owner' then raise exception 'owner invitations are not permitted'; end if;
  insert into public.organization_members(organization_id, user_id, role)
    values(target.organization_id, accepting_user_id, target.role)
    on conflict(organization_id, user_id) do update set role = excluded.role;
  update public.organization_invites set accepted_by = accepting_user_id, accepted_at = now()
    where id = target.id;
  select * into organization_value from public.organizations where id = target.organization_id;
  return jsonb_build_object(
    'organization', to_jsonb(organization_value),
    'role', target.role,
    'accepted_at', now()
  );
end;
$$;

create function public.internal_process_billing_event(
  target_event_id text,
  target_event_type text,
  target_customer_id text,
  target_product_id text,
  target_transaction_id text,
  target_occurred_at timestamptz,
  target_payload_sha256 text,
  target_status public.billing_subscription_status,
  target_expires_at timestamptz,
  target_will_renew boolean,
  pass_delta integer default 0
)
returns boolean language plpgsql security definer set search_path = '' as $$
declare inserted_count integer;
declare apply_state boolean;
begin
  insert into public.billing_events(
    event_id, event_type, revenuecat_customer_id, product_id, transaction_id,
    occurred_at, payload_sha256
  ) values (
    target_event_id, target_event_type, target_customer_id, target_product_id,
    target_transaction_id, target_occurred_at, target_payload_sha256
  ) on conflict(event_id) do nothing;
  get diagnostics inserted_count = row_count;
  if inserted_count = 0 then return false; end if;

  select ba.last_event_at is null or target_occurred_at >= ba.last_event_at into apply_state
  from public.billing_accounts ba where ba.revenuecat_customer_id = target_customer_id;
  if apply_state is null then raise exception 'billing account not found'; end if;
  apply_state := apply_state and target_event_type <> 'NON_RENEWING_PURCHASE';

  update public.billing_accounts set
    subscription_status = case
      when apply_state then target_status
      else subscription_status end,
    product_id = case
      when apply_state then target_product_id
      else product_id end,
    entitlement_expires_at = case
      when apply_state then target_expires_at
      else entitlement_expires_at end,
    will_renew = case
      when apply_state then target_will_renew
      else will_renew end,
    pass_balance = greatest(0, pass_balance + pass_delta),
    last_event_at = case when apply_state
      then greatest(coalesce(last_event_at, target_occurred_at), target_occurred_at)
      else last_event_at end,
    last_synced_at = now(), updated_at = now()
  where revenuecat_customer_id = target_customer_id;
  if not found then raise exception 'billing account not found'; end if;
  if apply_state and target_status in ('trialing', 'active', 'grace_period') then
    update public.challenges c set
      access_source = 'organizer_plus', participant_limit = 250, collaborator_limit = 5,
      premium_access_until = null
    from public.billing_accounts ba
    where ba.revenuecat_customer_id = target_customer_id
      and c.organization_id = ba.organization_id and c.status in ('active', 'revealed');
  elsif apply_state and target_status in ('cancelled', 'expired', 'billing_issue') then
    update public.challenges c set
      premium_access_until = greatest(c.reveal_at + interval '30 days', now())
    from public.billing_accounts ba
    where ba.revenuecat_customer_id = target_customer_id
      and c.organization_id = ba.organization_id
      and c.access_source = 'organizer_plus' and c.status in ('active', 'revealed');
  end if;
  update public.billing_events set processed_at = now() where event_id = target_event_id;
  return true;
end;
$$;

create function public.internal_merge_guest_account(guest_user_id uuid, target_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if guest_user_id = target_user_id then return; end if;
  update public.challenge_members cm set user_id = target_user_id
    where user_id = guest_user_id
      and not exists (
        select 1 from public.challenge_members target
        where target.challenge_id = cm.challenge_id and target.user_id = target_user_id
      );
  delete from public.challenge_members where user_id = guest_user_id;
  update public.contribution_owners co set participant_id = target_user_id
    where participant_id = guest_user_id
      and not exists (
        select 1 from public.contribution_owners target
        where target.contribution_id = co.contribution_id and target.participant_id = target_user_id
      );
  update public.profiles target set
    display_name = coalesce(nullif(target.display_name, ''), guest.display_name), updated_at = now()
    from public.profiles guest
    where target.user_id = target_user_id and guest.user_id = guest_user_id;
end;
$$;

create function public.internal_join_challenge(
  joining_user_id uuid,
  challenge_code text,
  participant_display_name text,
  participant_privacy public.privacy_mode,
  participant_is_anonymous boolean
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare target public.challenges;
declare participant_count integer;
begin
  select * into target from public.challenges
    where invitation_code = upper(challenge_code) for update;
  if not found then raise exception 'challenge code not found'; end if;
  if target.status <> 'active' then raise exception 'challenge is not accepting participants'; end if;
  if not exists (
    select 1 from public.challenge_members
    where challenge_id = target.id and user_id = joining_user_id
  ) then
    select count(*) into participant_count from public.challenge_members
      where challenge_id = target.id and role = 'participant';
    if participant_count >= target.participant_limit then raise exception 'participant limit reached'; end if;
  end if;
  insert into public.challenge_members(challenge_id, user_id, role, display_name, privacy)
    values(target.id, joining_user_id, 'participant', participant_display_name, participant_privacy)
    on conflict(challenge_id, user_id) do update
      set display_name = excluded.display_name, privacy = excluded.privacy;
  insert into public.profiles(user_id, display_name, is_demo, updated_at)
    values(joining_user_id, participant_display_name, participant_is_anonymous, now())
    on conflict(user_id) do update
      set display_name = excluded.display_name, is_demo = excluded.is_demo, updated_at = now();
  return to_jsonb(target);
end;
$$;

create function public.internal_delete_organization(target_organization_id uuid, requesting_owner_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.organization_members
    where organization_id = target_organization_id and user_id = requesting_owner_id and role = 'owner'
  ) then raise exception 'organization ownership required'; end if;
  delete from public.organizations where id = target_organization_id;
end;
$$;

create function public.internal_transfer_organization_ownership(
  target_organization_id uuid,
  current_owner_id uuid,
  new_owner_id uuid
)
returns void language plpgsql security definer set search_path = '' as $$
declare account public.billing_accounts;
begin
  perform 1 from public.organizations where id = target_organization_id for update;
  if not exists (
    select 1 from public.organization_members
    where organization_id = target_organization_id and user_id = current_owner_id and role = 'owner'
  ) then raise exception 'organization ownership required'; end if;
  if not exists (
    select 1 from public.organization_members
    where organization_id = target_organization_id and user_id = new_owner_id
  ) then raise exception 'new owner must already be a collaborator'; end if;
  select * into account from public.billing_accounts where organization_id = target_organization_id for update;
  if account.pass_balance > 0 then raise exception 'redeem purchased PASS credits before ownership transfer'; end if;
  update public.challenges set premium_access_until = greatest(reveal_at + interval '30 days', now())
    where organization_id = target_organization_id and access_source = 'organizer_plus';
  update public.organization_members set role = 'admin'
    where organization_id = target_organization_id and user_id = current_owner_id;
  update public.organization_members set role = 'owner'
    where organization_id = target_organization_id and user_id = new_owner_id;
  update public.organizations set created_by = new_owner_id, updated_at = now()
    where id = target_organization_id;
  update public.billing_accounts set
    owner_user_id = new_owner_id, revenuecat_customer_id = new_owner_id::text,
    subscription_status = 'none', product_id = null, entitlement_expires_at = null,
    will_renew = false, last_event_at = null, updated_at = now()
    where organization_id = target_organization_id;
end;
$$;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.organization_invites enable row level security;
alter table public.billing_accounts enable row level security;
alter table public.billing_events enable row level security;
alter table public.challenge_access_grants enable row level security;
alter table public.pass_redemptions enable row level security;

create policy "members read organizations" on public.organizations for select to authenticated
  using (private.is_organization_member(id));
create policy "members read organization roster" on public.organization_members for select to authenticated
  using (private.is_organization_member(organization_id));
create policy "owners read billing account" on public.billing_accounts for select to authenticated
  using (owner_user_id = (select auth.uid()) and not private.is_anonymous_user());
create policy "owners read challenge grants" on public.challenge_access_grants for select to authenticated
  using (
    private.organization_role_for(organization_id) = 'owner'
    and not private.is_anonymous_user()
  );

-- Organization roles supersede the legacy per-challenge organizer row for
-- workspace-owned challenges, while retaining it for old/demo records.
create or replace function private.is_challenge_organizer(requested_challenge_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.challenges c
    where c.id = requested_challenge_id and (
      private.can_review_organization(c.organization_id)
      or exists (
        select 1 from public.challenge_members cm
        where cm.challenge_id = requested_challenge_id
          and cm.user_id = (select auth.uid()) and cm.role = 'organizer'
      )
    )
  );
$$;

revoke all on table public.organizations, public.organization_members,
  public.organization_invites, public.billing_accounts, public.billing_events,
  public.challenge_access_grants, public.pass_redemptions from anon, authenticated;
grant select on table public.organizations, public.organization_members,
  public.billing_accounts, public.challenge_access_grants to authenticated;
grant all on table public.organizations, public.organization_members,
  public.organization_invites, public.billing_accounts, public.billing_events,
  public.challenge_access_grants, public.pass_redemptions to service_role;

revoke all on function private.is_anonymous_user() from public, anon, authenticated;
revoke all on function private.organization_role_for(uuid) from public, anon, authenticated;
revoke all on function private.is_organization_member(uuid) from public, anon, authenticated;
revoke all on function private.can_manage_organization(uuid) from public, anon, authenticated;
revoke all on function private.can_review_organization(uuid) from public, anon, authenticated;
revoke all on function private.has_current_plus(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.has_challenge_premium_access(uuid, timestamptz) from public, anon, authenticated;
grant execute on function private.is_anonymous_user() to service_role;
grant execute on function private.organization_role_for(uuid) to service_role;
grant execute on function private.is_organization_member(uuid) to service_role;
grant execute on function private.can_manage_organization(uuid) to service_role;
grant execute on function private.can_review_organization(uuid) to service_role;
grant execute on function private.has_current_plus(uuid, timestamptz) to service_role;
grant execute on function private.has_challenge_premium_access(uuid, timestamptz) to service_role;
-- These security-definer helpers are the predicates used by client-facing RLS
-- policies. Authenticated callers can only ask about access derived from their
-- own auth.uid(); granting EXECUTE is required for the policies to evaluate.
grant execute on function private.is_anonymous_user() to authenticated;
grant execute on function private.organization_role_for(uuid) to authenticated;
grant execute on function private.is_organization_member(uuid) to authenticated;
grant execute on function private.can_manage_organization(uuid) to authenticated;
grant execute on function private.can_review_organization(uuid) to authenticated;
grant execute on function private.has_current_plus(uuid, timestamptz) to authenticated;
grant execute on function private.has_challenge_premium_access(uuid, timestamptz) to authenticated;

revoke all on function public.organization_access_snapshot(uuid, uuid) from public, anon;
grant execute on function public.organization_access_snapshot(uuid, uuid) to authenticated, service_role;
revoke all on function public.internal_record_event_pass(uuid, uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.internal_record_event_pass(uuid, uuid, uuid, text) to service_role;
revoke all on function public.internal_begin_event_pass_redemption(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.internal_begin_event_pass_redemption(uuid, uuid, uuid) to service_role;
revoke all on function public.internal_complete_event_pass_redemption(uuid, text) from public, anon, authenticated;
grant execute on function public.internal_complete_event_pass_redemption(uuid, text) to service_role;
revoke all on function public.internal_create_organization(uuid, text, text) from public, anon, authenticated;
grant execute on function public.internal_create_organization(uuid, text, text) to service_role;
revoke all on function public.internal_accept_organization_invite(uuid, text) from public, anon, authenticated;
grant execute on function public.internal_accept_organization_invite(uuid, text) to service_role;
revoke all on function public.internal_process_billing_event(text, text, text, text, text, timestamptz, text, public.billing_subscription_status, timestamptz, boolean, integer) from public, anon, authenticated;
grant execute on function public.internal_process_billing_event(text, text, text, text, text, timestamptz, text, public.billing_subscription_status, timestamptz, boolean, integer) to service_role;
revoke all on function public.internal_merge_guest_account(uuid, uuid) from public, anon, authenticated;
grant execute on function public.internal_merge_guest_account(uuid, uuid) to service_role;
revoke all on function public.internal_join_challenge(uuid, text, text, public.privacy_mode, boolean) from public, anon, authenticated;
grant execute on function public.internal_join_challenge(uuid, text, text, public.privacy_mode, boolean) to service_role;
revoke all on function public.internal_delete_organization(uuid, uuid) from public, anon, authenticated;
grant execute on function public.internal_delete_organization(uuid, uuid) to service_role;
revoke all on function public.internal_transfer_organization_ownership(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.internal_transfer_organization_ownership(uuid, uuid, uuid) to service_role;

create trigger organizations_touch_updated_at before update on public.organizations
for each row execute function private.touch_updated_at();
create trigger billing_accounts_touch_updated_at before update on public.billing_accounts
for each row execute function private.touch_updated_at();
