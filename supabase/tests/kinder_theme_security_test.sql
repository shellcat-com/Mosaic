begin;
select plan(10);

select has_column('public', 'challenges', 'theme_id', 'challenge stores the published theme id');
select has_column('public', 'challenges', 'theme_palette_id', 'challenge stores the tuned palette');
select has_column('public', 'challenges', 'theme_seed', 'challenge stores deterministic artwork seed');
select has_column('public', 'challenges', 'theme_revision', 'challenge stores catalog revision');

insert into public.challenges (id, name, purpose, goal, reveal_at, invitation_code)
values ('24000000-0000-4000-8000-000000000001', 'Legacy theme', 'Fallback coverage', 10,
        now() + interval '1 day', 'THEME1');

select is((select theme_id from public.challenges where id = '24000000-0000-4000-8000-000000000001'),
          'neighborhood-quilt', 'legacy rows receive Neighborhood Quilt');
select is((select theme_palette_id from public.challenges where id = '24000000-0000-4000-8000-000000000001'),
          'signature', 'legacy rows receive the signature palette');
select throws_ok(
  $$update public.challenges set theme_palette_id = 'neon_filter'
    where id = '24000000-0000-4000-8000-000000000001'$$,
  '23514', null, 'unknown palette is rejected'
);
select throws_ok(
  $$update public.challenges set theme_revision = 0
    where id = '24000000-0000-4000-8000-000000000001'$$,
  '23514', null, 'invalid catalog revision is rejected'
);

insert into auth.users (id, email, raw_user_meta_data)
values ('14000000-0000-4000-8000-000000000001', 'theme-organizer@mosaic.test', '{}');
insert into public.challenge_members (challenge_id, user_id, role, display_name)
values ('24000000-0000-4000-8000-000000000001', '14000000-0000-4000-8000-000000000001', 'organizer', 'Organizer');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"14000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select throws_ok(
  $$update public.challenges set theme_id = 'future-unpublished-artwork'
    where id = '24000000-0000-4000-8000-000000000001'$$,
  '42501', null, 'organizers cannot bypass the configure-challenge publication boundary'
);
select is((select theme_id from public.challenges where id = '24000000-0000-4000-8000-000000000001'),
          'neighborhood-quilt', 'failed direct update leaves published artwork intact');

select * from finish();
rollback;
