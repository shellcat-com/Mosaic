begin;
select plan(13);

insert into auth.users (id, email, raw_user_meta_data) values
  ('12000000-0000-4000-8000-000000000001', 'event-owner@mosaic.test', '{}'),
  ('12000000-0000-4000-8000-000000000002', 'event-member@mosaic.test', '{}'),
  ('12000000-0000-4000-8000-000000000003', 'event-outsider@mosaic.test', '{}');

insert into public.challenges (
  id, name, purpose, goal, start_at, reveal_at, status,
  invitation_code, is_showcase
) values (
  '22000000-0000-4000-8000-000000000001',
  'Event Security', 'Verify event isolation', 10, now(), now() + interval '2 days',
  'active', 'EVENT1', true
);

insert into public.challenge_members (challenge_id, user_id, role, display_name) values
  ('22000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000001', 'organizer', 'Owner'),
  ('22000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000002', 'participant', 'Member');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"12000000-0000-4000-8000-000000000002","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.event_notification_preferences (challenge_id, user_id)
    values ('22000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000002')$$,
  'member creates their own event preferences'
);
select is((select count(*)::integer from public.event_notification_preferences), 1,
          'member reads their own preference row');
select lives_ok(
  $$update public.event_notification_preferences set reveal_hour_before = false
    where challenge_id = '22000000-0000-4000-8000-000000000001'$$,
  'member updates their own reminder categories'
);
select is((select reveal_hour_before from public.event_notification_preferences), false,
          'preference update is retained');

select set_config('request.jwt.claims', '{"sub":"12000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select is((select count(*)::integer from public.event_notification_preferences), 0,
          'outsider cannot read member preferences');
select throws_ok(
  $$insert into public.event_notification_preferences (challenge_id, user_id)
    values ('22000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000003')$$,
  '42501', null, 'outsider cannot create challenge preferences'
);
select throws_ok($$select * from public.notification_devices$$, '42501', null,
                 'clients cannot read APNs device tokens');
select throws_ok($$select * from public.live_activity_tokens$$, '42501', null,
                 'clients cannot read Live Activity tokens');
select throws_ok($$select * from public.notification_deliveries$$, '42501', null,
                 'clients cannot read delivery records');

reset role;
insert into public.notification_devices (user_id, token, environment)
values ('12000000-0000-4000-8000-000000000002', repeat('a', 64), 'sandbox');
insert into public.live_activity_tokens (user_id, challenge_id, activity_id, token, environment)
values (
  '12000000-0000-4000-8000-000000000002',
  '22000000-0000-4000-8000-000000000001',
  'push-to-start:fixture', repeat('b', 64), 'sandbox'
);
select is((select count(*)::integer from public.notification_devices), 1,
          'service role can retain one registered device');
select is((select count(*)::integer from public.live_activity_tokens), 1,
          'service role can retain one challenge-scoped Live Activity token');

update public.challenges
set reveal_at = reveal_at + interval '1 hour'
where id = '22000000-0000-4000-8000-000000000001';
select is(
  (select schedule_revision from public.challenges
   where id = '22000000-0000-4000-8000-000000000001'),
  2,
  'organizer rescheduling increments the revision exactly once'
);
select is(
  (select count(*)::integer from public.notification_deliveries
   where kind = 'schedule_changed' and user_id = '12000000-0000-4000-8000-000000000002'),
  1,
  'rescheduling enqueues one idempotent member delivery'
);

select * from finish();
rollback;
