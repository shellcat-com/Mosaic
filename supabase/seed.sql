-- Deterministic local-only v3 fixtures. Production creates profiles through
-- Sign in with Apple and never ships these identities.
insert into auth.users (id, email, raw_user_meta_data) values
  ('10000000-0000-4000-8000-000000000001', 'organizer@mosaic.local', '{}'),
  ('10000000-0000-4000-8000-000000000002', 'member@mosaic.local', '{}')
on conflict (id) do nothing;

insert into public.mosaic_v3_profiles (id, display_name) values
  ('10000000-0000-4000-8000-000000000001', 'Maya'),
  ('10000000-0000-4000-8000-000000000002', 'Noah')
on conflict (id) do update set display_name = excluded.display_name;

insert into public.mosaic_v3_mosaics (
  id, creator_id, name, community_name, description, invitation_code,
  artwork_id, film_look_id, shot_limit, tile_goal, start_at, reveal_at
) values (
  '20000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  'Neighborhood Garden Day', 'Willow Street',
  'Small acts that help our shared garden feel cared for.', 'GARDEN24',
  'a0000000-0000-4000-8000-000000000001', 'garden', 24, 25,
  now() - interval '1 hour', now() + interval '7 days'
) on conflict (id) do update set reveal_at = excluded.reveal_at;

insert into public.mosaic_v3_members(mosaic_id, profile_id, role) values
  ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','creator'),
  ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','member')
on conflict do nothing;

insert into public.mosaic_v3_kindness_activities(id,mosaic_id,title,purpose,sort_order) values
  ('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Water a thirsty planter','Give one overlooked corner a little care.',0),
  ('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','Welcome someone new','Help a neighbor feel known.',1),
  ('30000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000001','Pick up a shared space','Leave a common place gentler than you found it.',2)
on conflict (id) do nothing;
