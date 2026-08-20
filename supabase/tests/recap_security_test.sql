begin;
select plan(14);

insert into auth.users (id, email, raw_user_meta_data)
values
  ('10000000-0000-4000-8000-000000000001', 'recap-owner@mosaic.test', '{}'),
  ('10000000-0000-4000-8000-000000000002', 'recap-organizer@mosaic.test', '{}'),
  ('10000000-0000-4000-8000-000000000003', 'recap-member@mosaic.test', '{}'),
  ('10000000-0000-4000-8000-000000000004', 'recap-outsider@mosaic.test', '{}');

insert into public.organizations(id,name,created_by) values
 ('30000000-0000-4000-8000-000000000099','Recap workspace','10000000-0000-4000-8000-000000000002');
insert into public.organization_members(organization_id,user_id,role) values
 ('30000000-0000-4000-8000-000000000099','10000000-0000-4000-8000-000000000002','owner');

insert into public.challenges (id, organizer_id, organization_id, created_by, name, purpose, goal, reveal_at, status, invitation_code)
values ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002',
        '30000000-0000-4000-8000-000000000099','10000000-0000-4000-8000-000000000002',
        'Recap RLS', 'Verify recap isolation', 5, now() - interval '1 minute', 'revealed', 'RECAP1');

insert into public.challenge_members (challenge_id, user_id, role, display_name)
values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'participant', 'Owner'),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'organizer', 'Organizer'),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 'participant', 'Member');

insert into public.missions (id, challenge_id, title, detail, category, minutes, effort, accepted_evidence)
values ('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
        'Recap mission', 'Test', 'community', 5, 'Easy', array['photo']::public.evidence_method[]);

insert into public.contributions (id, challenge_id, mission_id, emotion, evidence_method, status, tile_position)
values ('40000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
        '30000000-0000-4000-8000-000000000001', 'hopeful', 'photo', 'revealed', 0);
insert into public.contribution_owners (contribution_id, participant_id)
values ('40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001');
insert into public.memories (id, contribution_id, challenge_id, media_path, story_text, show_identity,
                             export_consent, review_status, approved_at)
values ('50000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000001', 'recap/test.jpg', 'A revealed memory', true,
        true, 'approved', now());
insert into public.impact_receipts (challenge_id, accepted_actions, participant_count, mission_totals)
values ('20000000-0000-4000-8000-000000000001', 1, 1, '{"community":1}');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select is((select count(*)::integer from public.recap_sources), 1, 'revealed member reads consented recap source');
select is((select count(*)::integer from public.impact_receipts), 1, 'revealed member reads verified impact receipt');
select lives_ok(
  $$insert into public.recap_exports (challenge_id, creator_id, fingerprint, preset_id)
    values ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', repeat('a', 64), 'golden')$$,
  'member creates only their own export job'
);
select throws_ok(
  $$insert into public.recap_exports (challenge_id, creator_id, fingerprint, preset_id)
    values ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', repeat('b', 64), 'golden')$$,
  '42501', null, 'member cannot create another user export job'
);
select lives_ok(
  $$update public.recap_exports set status = 'completed_uploaded', visibility = 'challenge',
      storage_path = '10000000-0000-4000-8000-000000000003/recap.mp4'
    where fingerprint = repeat('a', 64)$$,
  'creator can publish their own export to the challenge'
);

select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((select count(*)::integer from public.recap_exports where fingerprint = repeat('a', 64)), 1,
          'challenge member reads a shared completed export');
select is((select participant_display_name from public.recap_sources limit 1), 'Owner',
          'allowed attribution is visible only after reveal');

select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
select is((select count(*)::integer from public.recap_sources), 0, 'outsider cannot read recap sources');
select is((select count(*)::integer from public.impact_receipts), 0, 'outsider cannot read impact receipts');
select is((select count(*)::integer from public.recap_exports), 0, 'outsider cannot read exports');
select throws_ok(
  $$insert into public.recap_exports (challenge_id, creator_id, fingerprint, preset_id)
    values ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004', repeat('c', 64), 'golden')$$,
  '42501', null, 'outsider cannot create an export job'
);

select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
insert into public.user_blocks (blocker_id, blocked_id)
values ('10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001');
select is((select count(*)::integer from public.recap_sources), 0, 'blocked contributor disappears from recap source view');
delete from public.user_blocks
where blocker_id = '10000000-0000-4000-8000-000000000003' and blocked_id = '10000000-0000-4000-8000-000000000001';
insert into public.memory_reports (memory_id, reporter_id, reason)
values ('50000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 'Privacy concern');
select is((select count(*)::integer from public.recap_sources), 0, 'reported memory disappears immediately from recap source view');
select isnt((select reported_at from public.memories where id = '50000000-0000-4000-8000-000000000001'), null,
            'report trigger flags the normalized memory record');

select * from finish();
rollback;
