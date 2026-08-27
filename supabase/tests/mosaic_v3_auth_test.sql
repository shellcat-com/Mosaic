begin;
set local search_path = public, extensions, auth;
select plan(8);

insert into auth.users(id,email,raw_user_meta_data,is_anonymous) values
  ('90000000-0000-4000-8000-000000000001','apple-v3@mosaic.test','{}',false),
  ('90000000-0000-4000-8000-000000000002','anonymous-v3@mosaic.test','{}',true),
  ('90000000-0000-4000-8000-000000000003','email-v3@mosaic.test','{}',false);

insert into auth.identities(provider_id,user_id,identity_data,provider) values
  ('apple-provider-1','90000000-0000-4000-8000-000000000001','{}','apple'),
  ('apple-provider-2','90000000-0000-4000-8000-000000000002','{}','apple'),
  ('email-provider-1','90000000-0000-4000-8000-000000000003','{}','email');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000002","role":"authenticated","is_anonymous":true}',true);
select throws_ok(
  $$select public.v3_auth_profile()$$,
  '42501','apple_account_required',
  'anonymous users cannot enter the V3 account boundary'
);

select set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000003","role":"authenticated","is_anonymous":false}',true);
select throws_ok(
  $$select public.v3_auth_profile()$$,
  '42501','apple_account_required',
  'permanent non-Apple users cannot enter the Apple-only boundary'
);

select set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}',true);
select is(public.v3_auth_profile()->'profile','null'::jsonb,'new Apple user starts without a display profile');
select throws_ok(
  $$select public.v3_auth_save_profile('x')$$,
  '22023','invalid_display_name',
  'display names shorter than two characters are rejected'
);
select is(public.v3_auth_save_profile('  Ada Lovelace  ')->>'display_name','Ada Lovelace','display names are normalized and saved');
select is(public.v3_auth_profile()->'profile'->>'display_name','Ada Lovelace','saved profile is restored');
reset role;
select is(to_regprocedure('public.v3_delete_account()')::text,null,'legacy direct account deletion RPC is absent');
select is(to_regprocedure('public.v3_auth_delete_account()')::text,null,'account deletion is reserved for the authenticated Edge Function');

select * from finish();
rollback;
