insert into public.challenges (
  id, organizer_id, name, purpose, goal, reveal_at, status, invitation_code, is_showcase
) values (
  '11111111-1111-4111-8111-111111111111',
  null,
  'A Kinder Block',
  '40 small acts to make our neighborhood feel closer.',
  40,
  now() + interval '5 days',
  'active',
  'KIND42',
  true
) on conflict (id) do update set reveal_at = excluded.reveal_at, status = 'active';

insert into public.missions (
  id, challenge_id, title, detail, category, minutes, effort, accepted_evidence, sort_order
) values
  ('20000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'Leave a kind note', 'Brighten someone’s day with a few kind words.', 'encouragement', 5, 'Easy', array['reflection', 'photo']::public.evidence_method[], 1),
  ('20000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'Clean a shared space', 'Leave one small corner of your community better than you found it.', 'community', 20, 'Hands-on', array['photo', 'video', 'organizer']::public.evidence_method[], 2),
  ('20000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'Donate a useful item', 'Give something in good condition to a neighbor or local organization.', 'giving', 15, 'Easy', array['photo', 'receipt']::public.evidence_method[], 3),
  ('20000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'Teach a useful skill', 'Share something practical that helps another person feel more capable.', 'teaching', 30, 'Together', array['reflection', 'video']::public.evidence_method[], 4),
  ('20000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', 'Support something local', 'Show up for a neighborhood group, maker, or nonprofit.', 'support', 20, 'Flexible', array['receipt', 'photo', 'organizer']::public.evidence_method[], 5),
  ('20000000-0000-4000-8000-000000000006', '11111111-1111-4111-8111-111111111111', 'Check in with someone', 'Reach out and make room for a genuine conversation.', 'connection', 10, 'Quiet', array['reflection', 'organizer']::public.evidence_method[], 6)
on conflict (id) do nothing;

insert into public.contributions (
  id, challenge_id, mission_id, emotion, evidence_method, status, verification_level, tile_position, created_at
) values
  ('30000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000001', 'hopeful', 'reflection', 'placed', 'self_attested', 0, now() - interval '12 hours'),
  ('30000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000002', 'joyful', 'photo', 'placed', 'organizer_verified', 1, now() - interval '11 hours'),
  ('30000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000003', 'caring', 'receipt', 'placed', 'organizer_verified', 2, now() - interval '10 hours'),
  ('30000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000004', 'calm', 'video', 'placed', 'organizer_verified', 3, now() - interval '9 hours'),
  ('30000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000005', 'hopeful', 'organizer', 'placed', 'organizer_verified', 4, now() - interval '8 hours'),
  ('30000000-0000-4000-8000-000000000006', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000006', 'joyful', 'reflection', 'placed', 'self_attested', 5, now() - interval '7 hours'),
  ('30000000-0000-4000-8000-000000000007', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000001', 'caring', 'photo', 'placed', 'organizer_verified', 6, now() - interval '6 hours'),
  ('30000000-0000-4000-8000-000000000008', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000002', 'calm', 'organizer', 'placed', 'organizer_verified', 7, now() - interval '5 hours'),
  ('30000000-0000-4000-8000-000000000009', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000003', 'hopeful', 'receipt', 'placed', 'organizer_verified', 8, now() - interval '4 hours'),
  ('30000000-0000-4000-8000-000000000010', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000004', 'joyful', 'reflection', 'placed', 'self_attested', 9, now() - interval '3 hours'),
  ('30000000-0000-4000-8000-000000000011', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000005', 'caring', 'photo', 'placed', 'organizer_verified', 10, now() - interval '2 hours'),
  ('30000000-0000-4000-8000-000000000012', '11111111-1111-4111-8111-111111111111', '20000000-0000-4000-8000-000000000006', 'calm', 'organizer', 'placed', 'organizer_verified', 11, now() - interval '1 hour')
on conflict (id) do nothing;
