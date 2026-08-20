begin;
select plan(10);

insert into auth.users (id, email, raw_user_meta_data)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'participant@mosaic.test', '{}'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'organizer@mosaic.test', '{}'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'outsider@mosaic.test', '{}'),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'other-member@mosaic.test', '{}');

insert into public.organizations(id,name,created_by) values
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','RLS workspace','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
insert into public.organization_members(organization_id,user_id,role) values
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','owner');

insert into public.challenges (id, organizer_id, organization_id, created_by, name, purpose, goal, reveal_at, invitation_code)
values ('44444444-4444-4444-8444-444444444444', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'RLS Test', 'Verify isolation', 5, now() + interval '1 day', 'RLST42');

insert into public.challenge_members (challenge_id, user_id, role, display_name)
values
  ('44444444-4444-4444-8444-444444444444', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'participant', 'A'),
  ('44444444-4444-4444-8444-444444444444', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'organizer', 'B'),
  ('44444444-4444-4444-8444-444444444444', 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'participant', 'D');

insert into public.missions (id, challenge_id, title, detail, category, minutes, effort, accepted_evidence)
values ('55555555-5555-4555-8555-555555555555', '44444444-4444-4444-8444-444444444444', 'Test Mission', 'Test', 'community', 5, 'Easy', array['photo']::public.evidence_method[]);

insert into public.contributions (id, challenge_id, mission_id, emotion, evidence_method, status)
values ('66666666-6666-4666-8666-666666666666', '44444444-4444-4444-8444-444444444444', '55555555-5555-4555-8555-555555555555', 'hopeful', 'photo', 'pending_review');
insert into public.contribution_owners (contribution_id, participant_id)
values ('66666666-6666-4666-8666-666666666666', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
insert into public.evidence_submissions (contribution_id, media_path, mime_type, file_size)
values ('66666666-6666-4666-8666-666666666666', 'private/test.jpg', 'image/jpeg', 128);
insert into public.memories (contribution_id, challenge_id, story_text, review_status)
values ('66666666-6666-4666-8666-666666666666', '44444444-4444-4444-8444-444444444444', 'Sealed story', 'approved');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
select is((select count(*)::integer from public.challenges where id = '44444444-4444-4444-8444-444444444444'), 1, 'participant reads joined challenge');
select is((select count(*)::integer from public.contributions where challenge_id = '44444444-4444-4444-8444-444444444444'), 1, 'participant reads safe tile data');
select is((select count(*)::integer from public.evidence_submissions), 1, 'participant reads own evidence');
select is((select count(*)::integer from public.memories), 1, 'participant reads own sealed memory');
select throws_ok(
  $$insert into public.challenges (name, purpose, goal, reveal_at, invitation_code) values ('Attack', 'Denied', 1, now(), 'ATTACK')$$,
  '42501', null, 'authenticated clients cannot write tables directly'
);

select set_config('request.jwt.claims', '{"sub":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","role":"authenticated"}', true);
select is((select count(*)::integer from public.memories), 0, 'another member cannot read an approved memory before reveal');

select set_config('request.jwt.claims', '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}', true);
select is((select count(*)::integer from public.challenges where id = '44444444-4444-4444-8444-444444444444'), 0, 'outsider cannot read challenge');
select is((select count(*)::integer from public.contributions where challenge_id = '44444444-4444-4444-8444-444444444444'), 0, 'outsider cannot read tiles');
select is((select count(*)::integer from public.evidence_submissions), 0, 'outsider cannot read evidence');

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}', true);
select is((select count(*)::integer from public.evidence_submissions), 1, 'organizer can read challenge evidence');

select * from finish();
rollback;
