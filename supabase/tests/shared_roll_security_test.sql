begin;
select plan(14);

insert into auth.users (id, email, raw_user_meta_data) values
 ('11000000-0000-4000-8000-000000000001','roll-owner@mosaic.test','{}'),
 ('11000000-0000-4000-8000-000000000002','roll-organizer@mosaic.test','{}'),
 ('11000000-0000-4000-8000-000000000003','roll-member@mosaic.test','{}'),
 ('11000000-0000-4000-8000-000000000004','roll-outsider@mosaic.test','{}');

insert into public.organizations(id,name,created_by) values
 ('31000000-0000-4000-8000-000000000001','Roll workspace','11000000-0000-4000-8000-000000000002');
insert into public.organization_members(organization_id,user_id,role) values
 ('31000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000002','owner');

insert into public.challenges (id, organizer_id, organization_id, created_by, name, purpose, goal, reveal_at, status, invitation_code, camera_roll_enabled)
values ('21000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000002',
        '31000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000002',
        'Shared roll','Test prereveal isolation',5,now() + interval '1 day','active','ROLL11',true);
insert into public.challenge_members(challenge_id,user_id,role,display_name) values
 ('21000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000001','participant','Owner'),
 ('21000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000002','organizer','Organizer'),
 ('21000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000003','participant','Member');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$insert into public.shared_moments
 (id,challenge_id,creator_id,note,media_path,reveal_consent,export_consent,lifecycle)
 values ('61000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000001',
 '11000000-0000-4000-8000-000000000001','Private note',
 'moments/21000000-0000-4000-8000-000000000001/11000000-0000-4000-8000-000000000001/61000000-0000-4000-8000-000000000001.jpg',
 true,false,'upload_pending')$$,'owner creates a pending moment');
select is((select count(*)::integer from public.shared_moments),1,'owner reads own prereveal moment');
select throws_ok($$update public.shared_moments set lifecycle='approved' where id='61000000-0000-4000-8000-000000000001'$$,
 'P0001','only organizers approve shared moments','owner cannot self approve');

select set_config('request.jwt.claims','{"sub":"11000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select is((select count(*)::integer from public.shared_moments),0,'member cannot read prereveal media metadata');
select is((select count(*)::integer from public.recap_sources),0,'member sees no prereveal recap sources');

select set_config('request.jwt.claims','{"sub":"11000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*)::integer from public.shared_moments),1,'organizer can moderate prereveal moment');
update public.shared_moments set lifecycle='approved' where id='61000000-0000-4000-8000-000000000001';

reset role;
update public.challenges set status='revealed' where id='21000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select is((select count(*)::integer from public.shared_moments),1,'member reads approved moment after reveal');
select is((select count(*)::integer from public.recap_sources),0,'export consent off excludes moment from downloadable recap');

select set_config('request.jwt.claims','{"sub":"11000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
update public.shared_moments set export_consent=true where id='61000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims','{"sub":"11000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select is((select count(*)::integer from public.recap_sources),1,'explicit export consent includes standalone moment');
select is((select contribution_id from public.recap_sources limit 1),null::uuid,'standalone source has no contribution id');

select lives_ok($$insert into public.engagement_events(actor_id,challenge_id,client_event_id,name)
 values ('11000000-0000-4000-8000-000000000003','21000000-0000-4000-8000-000000000001',gen_random_uuid(),'camera_open')$$,
 'member appends allowlisted analytics');
select throws_ok($$insert into public.engagement_events(actor_id,challenge_id,client_event_id,name)
 values ('11000000-0000-4000-8000-000000000003','21000000-0000-4000-8000-000000000001',gen_random_uuid(),'typed_note')$$,
 '23514',null,'content-like analytics name is rejected');
select throws_ok($$select count(*) from public.engagement_events$$,'42501',null,'clients cannot read analytics events');

select set_config('request.jwt.claims','{"sub":"11000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select is((select count(*)::integer from public.shared_moments),0,'outsider cannot read revealed shared moments');

select * from finish();
rollback;
