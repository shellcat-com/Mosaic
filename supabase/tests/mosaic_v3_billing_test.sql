begin;
select plan(19);

insert into auth.users(id,email,raw_user_meta_data) values
 ('86000000-0000-4000-8000-000000000001','billing-a@mosaic.test','{}'),
 ('86000000-0000-4000-8000-000000000002','billing-b@mosaic.test','{}');
insert into public.profiles(id,display_name) values
 ('86000000-0000-4000-8000-000000000001','Billing A'),
 ('86000000-0000-4000-8000-000000000002','Billing B');

select ok(public.v3_internal_sync_billing(
 '86000000-0000-4000-8000-000000000001',false,'none',null,null,false,1
),'service reconciliation stores one PASS');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"86000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((public.v3_billing_snapshot()->>'passBalance')::int,1,'owner reads server PASS balance');
select throws_ok($$select public.v3_create_mosaic('{"name":"Bypass","communityName":"Test","description":"","activities":[{"title":"Help","purpose":"","sortOrder":0}],"artworkID":"a0000000-0000-4000-8000-000000000001","filmLookID":"garden","shotLimit":36,"startAt":"2029-01-01T00:00:00Z","revealAt":"2030-01-01T00:00:00Z","goal":100}'::jsonb)$$,'P0001','premium_required','free caller cannot bypass premium options');
select ok((public.v3_create_mosaic('{"name":"Free","communityName":"Test","description":"","activities":[{"title":"Help","purpose":"","sortOrder":0}],"artworkID":"a0000000-0000-4000-8000-000000000001","filmLookID":"sunwashed","shotLimit":12,"startAt":"2029-01-01T00:00:00Z","revealAt":"2030-01-01T00:00:00Z","goal":25}'::jsonb)->>'id') is not null,'free organizer creates one free Mosaic');
select throws_ok($$select public.v3_create_mosaic('{"name":"Second","communityName":"Test","description":"","activities":[{"title":"Help","purpose":"","sortOrder":0}],"artworkID":"a0000000-0000-4000-8000-000000000001","filmLookID":"sunwashed","shotLimit":12,"startAt":"2029-01-01T00:00:00Z","revealAt":"2030-01-01T00:00:00Z","goal":25}'::jsonb)$$,'P0001','free_creation_limit','free organizer cannot create a second unrevealed Mosaic');
reset role;

select ok(public.v3_internal_sync_billing(
 '86000000-0000-4000-8000-000000000001',true,'active','organizer_annual',now()+interval '1 month',true,1
),'Plus is reconciled from RevenueCat');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"86000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is(public.v3_create_mosaic('{"name":"Plus","communityName":"Test","description":"","activities":[{"title":"Help","purpose":"","sortOrder":0}],"artworkID":"a0000000-0000-4000-8000-000000000001","filmLookID":"garden","shotLimit":36,"startAt":"2029-01-01T00:00:00Z","revealAt":"2030-01-01T00:00:00Z","goal":100}'::jsonb)->>'accessSource','organizer_plus','Plus creates a 100-tile premium Mosaic');
reset role;
select ok(public.v3_internal_sync_billing(
 '86000000-0000-4000-8000-000000000001',false,'expired','organizer_annual',now()-interval '1 minute',false,1
),'subscription expiry is reconciled');
select is((select access_source from public.mosaics where name='Plus'),'organizer_plus','existing premium access remains captured after expiry');
select throws_ok($$update public.mosaics set access_source='free' where name='Plus'$$,'P0001','mosaic_access_source_is_immutable','captured event access cannot be downgraded');

select is((public.v3_internal_begin_pass_redemption(
 '87000000-0000-4000-8000-000000000001','86000000-0000-4000-8000-000000000001',
 '{"name":"Pass","communityName":"Test","description":"","activities":[{"title":"Help","purpose":"","sortOrder":0}],"artworkID":"a0000000-0000-4000-8000-000000000001","filmLookID":"afterglow","shotLimit":24,"startAt":"2029-01-01T00:00:00Z","revealAt":"2030-01-01T00:00:00Z","goal":36}'::jsonb
)->>'shouldDebit')::boolean,true,'PASS is atomically reserved');
select is((select pass_balance from public.billing_accounts where user_id='86000000-0000-4000-8000-000000000001'),0,'reservation consumes the local mirrored PASS');
select is((public.v3_internal_begin_pass_redemption(
 '87000000-0000-4000-8000-000000000001','86000000-0000-4000-8000-000000000001',
 '{"name":"Pass","communityName":"Test","description":"","activities":[{"title":"Help","purpose":"","sortOrder":0}],"artworkID":"a0000000-0000-4000-8000-000000000001","filmLookID":"afterglow","shotLimit":24,"startAt":"2029-01-01T00:00:00Z","revealAt":"2030-01-01T00:00:00Z","goal":36}'::jsonb
)->>'state'),'reserved','same request resumes without a second debit');
select ok(public.v3_internal_complete_pass_redemption('87000000-0000-4000-8000-000000000001','86000000-0000-4000-8000-000000000001') is not null,'reserved PASS creates the premium Mosaic');
select is(public.v3_internal_complete_pass_redemption('87000000-0000-4000-8000-000000000001','86000000-0000-4000-8000-000000000001'),(select mosaic_id from private.pass_redemptions where request_id='87000000-0000-4000-8000-000000000001'),'completion retry returns the same Mosaic');
select throws_ok($$select public.v3_internal_begin_pass_redemption('87000000-0000-4000-8000-000000000001','86000000-0000-4000-8000-000000000002','{}'::jsonb)$$,'23505','request_id_conflict','another user cannot claim a redemption request');

select is((public.v3_internal_record_revenuecat_event('evt_1','hash_1','INITIAL_PURCHASE','86000000-0000-4000-8000-000000000001')->>'duplicate')::boolean,false,'first webhook is recorded');
select is((public.v3_internal_record_revenuecat_event('evt_1','hash_1','INITIAL_PURCHASE','86000000-0000-4000-8000-000000000001')->>'duplicate')::boolean,true,'webhook replay is idempotent');
select throws_ok($$select public.v3_internal_record_revenuecat_event('evt_1','different','INITIAL_PURCHASE','86000000-0000-4000-8000-000000000001')$$,'23505','event_id_hash_conflict','same event ID with another payload is rejected');

select * from finish();
rollback;
