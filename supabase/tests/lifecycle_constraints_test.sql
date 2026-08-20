begin;
select plan(8);

select has_table('public', 'contributions', 'contributions table exists');
select has_table('public', 'evidence_submissions', 'private evidence table exists');
select col_is_pk('public', 'contribution_owners', 'contribution_id', 'ownership is one-to-one');
select ok(
  exists (
    select 1 from pg_constraint
    where conname = 'moderation_actions_idempotent'
      and conrelid = 'public.moderation_actions'::regclass
  ),
  'moderation replays have a database idempotency constraint'
);

select throws_ok(
  $$insert into public.missions (challenge_id, title, detail, category, minutes, effort, accepted_evidence)
    values ('11111111-1111-4111-8111-111111111111', 'Partner', 'Deferred', 'connection', 5, 'Easy', array['partner']::public.evidence_method[])$$,
  '23514', null, 'partner confirmation cannot be enabled in hackathon missions'
);

select throws_ok(
  $$insert into public.evidence_submissions (contribution_id, file_size)
    values ('30000000-0000-4000-8000-000000000001', 30000000)$$,
  '23514', null, 'evidence larger than 25 MB is rejected'
);

update public.challenges set reveal_at = now() - interval '1 minute', status = 'active' where is_showcase;
select private.activate_due_reveals();
select is(
  (select count(*)::integer from public.contributions contribution join public.challenges challenge on challenge.id = contribution.challenge_id where challenge.is_showcase and contribution.status = 'revealed'),
  12,
  'scheduled reveal advances every placed tile to revealed'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}', true);
select throws_ok(
  $$select public.internal_place_tile('30000000-0000-4000-8000-000000000001', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,
  '42501', null, 'clients cannot execute the internal placement function'
);

select * from finish();
rollback;
