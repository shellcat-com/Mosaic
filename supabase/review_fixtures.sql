-- Stable App Review fixture for the hosted Mosaic V3 backend.
--
-- This is intentionally not a migration or seed: run it only against the
-- release project when preparing App Review. The synthetic creator cannot log
-- in. Reviewers join REVIEW26 with their own Sign in with Apple account.

begin;

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token,
  is_sso_user,
  is_anonymous
) values (
  '00000000-0000-0000-0000-000000000000',
  '70000000-0000-4000-8000-000000000001',
  'authenticated',
  'authenticated',
  'app-review-fixture@mosaic.invalid',
  '',
  now(),
  '{"provider":"review_fixture","providers":["review_fixture"]}'::jsonb,
  '{"display_name":"Mosaic Review"}'::jsonb,
  now(),
  now(),
  '',
  '',
  false,
  false
)
on conflict (id) do update set
  updated_at = excluded.updated_at,
  raw_app_meta_data = excluded.raw_app_meta_data,
  raw_user_meta_data = excluded.raw_user_meta_data;

insert into public.mosaic_v3_profiles (id, display_name)
values ('70000000-0000-4000-8000-000000000001', 'Mosaic Review')
on conflict (id) do update set
  display_name = excluded.display_name,
  updated_at = now();

insert into public.mosaic_v3_mosaics (
  id,
  creator_id,
  name,
  community_name,
  description,
  invitation_code,
  artwork_id,
  film_look_id,
  shot_limit,
  tile_goal,
  start_at,
  reveal_at
) values (
  '70000000-0000-4000-8000-000000000002',
  '70000000-0000-4000-8000-000000000001',
  'App Review Kindness Garden',
  'Mosaic Review Community',
  'A synthetic, review-safe event for testing kindness activities, the sealed artwork, and the disposable camera.',
  'REVIEW26',
  'a0000000-0000-4000-8000-000000000001',
  'garden',
  12,
  9,
  '2026-08-01 00:00:00+00',
  '2027-12-31 23:59:00+00'
)
on conflict (id) do update set
  name = excluded.name,
  community_name = excluded.community_name,
  description = excluded.description,
  invitation_code = excluded.invitation_code,
  artwork_id = excluded.artwork_id,
  film_look_id = excluded.film_look_id,
  shot_limit = excluded.shot_limit,
  tile_goal = excluded.tile_goal,
  start_at = excluded.start_at,
  reveal_at = excluded.reveal_at,
  revealed_at = null,
  updated_at = now();

insert into public.mosaic_v3_members (mosaic_id, profile_id, role)
values (
  '70000000-0000-4000-8000-000000000002',
  '70000000-0000-4000-8000-000000000001',
  'creator'
)
on conflict (mosaic_id, profile_id) do update set role = excluded.role;

insert into public.mosaic_v3_kindness_activities (id, mosaic_id, title, purpose, sort_order) values
  ('70000000-0000-4000-8000-000000000011', '70000000-0000-4000-8000-000000000002', 'Thank someone who helped you', 'Notice an everyday act of care.', 0),
  ('70000000-0000-4000-8000-000000000012', '70000000-0000-4000-8000-000000000002', 'Make a shared space better', 'Leave a place kinder than you found it.', 1),
  ('70000000-0000-4000-8000-000000000013', '70000000-0000-4000-8000-000000000002', 'Check in with someone', 'Offer a genuine moment of connection.', 2),
  ('70000000-0000-4000-8000-000000000014', '70000000-0000-4000-8000-000000000002', 'Share something useful', 'Help someone with time, knowledge, or a resource.', 3)
on conflict (id) do update set
  title = excluded.title,
  purpose = excluded.purpose,
  sort_order = excluded.sort_order;

commit;
