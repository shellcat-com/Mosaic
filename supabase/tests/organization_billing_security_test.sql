begin;
select plan(24);

insert into auth.users(id, email, is_anonymous) values
  ('71000000-0000-4000-8000-000000000001', 'owner@mosaic.test', false),
  ('71000000-0000-4000-8000-000000000002', 'reviewer@mosaic.test', false),
  ('71000000-0000-4000-8000-000000000003', null, true),
  ('71000000-0000-4000-8000-000000000004', 'outsider@mosaic.test', false);

insert into public.organizations(id, name, created_by) values
  ('72000000-0000-4000-8000-000000000001', 'Protected workspace', '71000000-0000-4000-8000-000000000001');
insert into public.organization_members(organization_id, user_id, role) values
  ('72000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001', 'owner');
insert into public.billing_accounts(organization_id, owner_user_id, revenuecat_customer_id, pass_balance) values
  ('72000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001',
   '71000000-0000-4000-8000-000000000001', 1);
insert into public.challenges(
  id, organizer_id, organization_id, created_by, name, purpose, goal, start_at, reveal_at, invitation_code
) values (
  '73000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001',
  '72000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001',
  'Pass challenge', 'Test atomic access', 25, now(), now() + interval '7 days', 'PASST1'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}', true);
select is((select count(*)::integer from public.organizations), 1, 'owner reads own organization');
select is((select count(*)::integer from public.billing_accounts), 1, 'owner reads own billing account');

select set_config('request.jwt.claims', '{"sub":"71000000-0000-4000-8000-000000000004","role":"authenticated","is_anonymous":false}', true);
select is((select count(*)::integer from public.organizations), 0, 'outsider cannot read organization');
select is((select count(*)::integer from public.billing_accounts), 0, 'outsider cannot read billing state');

select set_config('request.jwt.claims', '{"sub":"71000000-0000-4000-8000-000000000003","role":"authenticated","is_anonymous":true}', true);
select throws_ok(
  $$insert into public.organizations(name, created_by) values ('Anonymous attack', '71000000-0000-4000-8000-000000000003')$$,
  '42501', null, 'anonymous users cannot create organizations through Data API'
);

reset role;
insert into public.organization_invites(
  organization_id, role, token_hash, created_by, expires_at
) values (
  '72000000-0000-4000-8000-000000000001', 'reviewer', repeat('a', 64),
  '71000000-0000-4000-8000-000000000001', now() + interval '7 days'
);
select lives_ok(
  $$select public.internal_accept_organization_invite(
    '71000000-0000-4000-8000-000000000002', repeat('a', 64))$$,
  'valid invitation can be accepted once'
);
select throws_ok(
  $$select public.internal_accept_organization_invite(
    '71000000-0000-4000-8000-000000000004', repeat('a', 64))$$,
  'P0001', 'invitation is invalid or already used', 'used invitation is rejected'
);
insert into public.organization_invites(
  organization_id, role, token_hash, created_by, created_at, expires_at
) values (
  '72000000-0000-4000-8000-000000000001', 'admin', repeat('d', 64),
  '71000000-0000-4000-8000-000000000001', now() - interval '8 days', now() - interval '1 day'
);
select throws_ok(
  $$select public.internal_accept_organization_invite(
    '71000000-0000-4000-8000-000000000004', repeat('d', 64))$$,
  'P0001', 'invitation is invalid or already used', 'expired invitation is rejected'
);

select ok(public.internal_process_billing_event(
  'event-new', 'INITIAL_PURCHASE', '71000000-0000-4000-8000-000000000001',
  'organizer_annual', 'txn-new', now(), repeat('b', 64), 'active', now() + interval '1 year', true, 0
), 'first webhook event is processed');
select is(public.internal_process_billing_event(
  'event-new', 'INITIAL_PURCHASE', '71000000-0000-4000-8000-000000000001',
  'organizer_annual', 'txn-new', now(), repeat('b', 64), 'active', now() + interval '1 year', true, 0
), false, 'duplicate webhook event is idempotent');
select ok(public.internal_process_billing_event(
  'event-stale', 'EXPIRATION', '71000000-0000-4000-8000-000000000001',
  'organizer_annual', 'txn-old', now() - interval '1 day', repeat('c', 64), 'expired', now() - interval '1 day', false, 0
), 'stale event is recorded');
select is((select subscription_status::text from public.billing_accounts where organization_id = '72000000-0000-4000-8000-000000000001'),
          'active', 'stale webhook cannot overwrite newer subscription state');
select ok(public.internal_process_billing_event(
  'event-pass', 'NON_RENEWING_PURCHASE', '71000000-0000-4000-8000-000000000001',
  'mosaic_event_pass', 'pass-purchase-txn', now() + interval '1 minute', repeat('e', 64),
  'none', null, false, 1
), 'event-pass purchase event is processed');
select is((select subscription_status::text from public.billing_accounts where organization_id = '72000000-0000-4000-8000-000000000001'),
          'active', 'event-pass purchase cannot overwrite subscription state');
select ok(public.internal_process_billing_event(
  'event-cancel', 'CANCELLATION', '71000000-0000-4000-8000-000000000001',
  'organizer_annual', 'txn-new', now() + interval '2 minutes', repeat('f', 64),
  'cancelled', now() + interval '11 months', false, 0
), 'subscription cancellation event is processed');
select is(
  private.has_current_plus('72000000-0000-4000-8000-000000000001', now()),
  true,
  'cancelled renewal retains Plus through its paid entitlement expiry'
);

select lives_ok(
  $$select public.internal_record_event_pass(
    '72000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000001',
    '71000000-0000-4000-8000-000000000001', 'pass-txn-1')$$,
  'one PASS grants challenge access'
);
select throws_ok(
  $$select public.internal_record_event_pass(
    '72000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000001',
    '71000000-0000-4000-8000-000000000001', 'pass-txn-2')$$,
  'P0001', 'challenge already has premium access', 'same challenge cannot spend a second PASS'
);

insert into public.challenges(
  id, organizer_id, organization_id, created_by, name, purpose, goal, start_at, reveal_at, invitation_code
) values (
  '73000000-0000-4000-8000-000000000002', '71000000-0000-4000-8000-000000000001',
  '72000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001',
  'Reserved pass challenge', 'Test retryable PASS reservation', 25, now(), now() + interval '7 days', 'PASST2'
);
update public.billing_accounts set pass_balance = 1
  where organization_id = '72000000-0000-4000-8000-000000000001';
select is(
  (public.internal_begin_event_pass_redemption(
    '72000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000002',
    '71000000-0000-4000-8000-000000000001'
  ) ->> 'already_completed')::boolean,
  false,
  'first PASS redemption creates a pending reservation'
);
select is(
  public.internal_begin_event_pass_redemption(
    '72000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000002',
    '71000000-0000-4000-8000-000000000001'
  ) ->> 'status',
  'pending',
  'a retry reuses the pending challenge reservation'
);
select is(
  (public.internal_complete_event_pass_redemption(
    '73000000-0000-4000-8000-000000000002', 'pass-txn-reserved'
  ) ->> 'already_completed')::boolean,
  false,
  'pending PASS redemption completes exactly once'
);
select is(
  (public.internal_complete_event_pass_redemption(
    '73000000-0000-4000-8000-000000000002', 'pass-txn-reserved'
  ) ->> 'already_completed')::boolean,
  true,
  'completion retry returns the existing grant without another debit'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"71000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}', true);
select is(
  (public.organization_access_snapshot(
    '72000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000001'
  ) ->> 'current_challenge_has_event_pass')::boolean,
  true,
  'access snapshot derives an event pass for the exact challenge'
);
select is(
  (public.organization_access_snapshot(
    '72000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000001'
  ) ->> 'participant_limit')::integer,
  250,
  'an active Plus subscription takes precedence over Event Pass limits'
);

select * from finish();
rollback;
