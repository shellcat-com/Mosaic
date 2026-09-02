begin;
select plan(28);

insert into auth.users(id,email,raw_user_meta_data) values
 ('91000000-0000-4000-8000-000000000001','owner-v3@mosaic.test','{}'),
 ('91000000-0000-4000-8000-000000000002','member-a-v3@mosaic.test','{}'),
 ('91000000-0000-4000-8000-000000000003','member-b-v3@mosaic.test','{}'),
 ('91000000-0000-4000-8000-000000000004','outsider-v3@mosaic.test','{}'),
 ('91000000-0000-4000-8000-000000000005','reporter-v3@mosaic.test','{}');
insert into public.mosaic_v3_profiles(id,display_name) values
 ('91000000-0000-4000-8000-000000000001','Owner'),
 ('91000000-0000-4000-8000-000000000002','Member A'),
 ('91000000-0000-4000-8000-000000000003','Member B'),
 ('91000000-0000-4000-8000-000000000004','Outsider'),
 ('91000000-0000-4000-8000-000000000005','Reporter');
insert into public.mosaic_v3_mosaics(id,creator_id,name,community_name,description,invitation_code,artwork_id,film_look_id,shot_limit,tile_goal,start_at,reveal_at)
values('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','RLS Mosaic','Test Community','Boundary test','SECURE24',
 'a0000000-0000-4000-8000-000000000001','sunwashed',12,9,now()-interval '1 hour',now()+interval '1 day');
insert into public.mosaic_v3_members(mosaic_id,profile_id,role) values
 ('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','creator'),
 ('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000002','member'),
 ('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000003','member'),
 ('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000005','member');
insert into public.mosaic_v3_kindness_activities(id,mosaic_id,title,purpose,sort_order) values
 ('93000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','Help someone','Be present',0),
 ('93000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000001','Care for a place','Leave it better',1);
insert into public.mosaic_v3_kindness_contributions(id,mosaic_id,activity_id,participant_id,tile_position,note) values
 ('94000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000002',0,'A private note'),
 ('94000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000003',1,'Another private note');
insert into public.mosaic_v3_event_photos(id,mosaic_id,photographer_id,storage_path,mime_type,byte_count,pixel_width,pixel_height,film_look_id,state) values
 ('95000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000001/91000000-0000-4000-8000-000000000002/95000000-0000-4000-8000-000000000001.jpg','image/jpeg',1000,100,100,'sunwashed','eligible'),
 ('95000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000003','92000000-0000-4000-8000-000000000001/91000000-0000-4000-8000-000000000003/95000000-0000-4000-8000-000000000002.jpg','image/jpeg',1000,100,100,'sunwashed','eligible');
insert into private.mosaic_v3_artwork_reveal_packages(mosaic_id,ciphertext_path,checksum,encryption_key,nonce) values
 ('92000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001/artwork.aesgcm','abc123','test-key','test-nonce');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from public.mosaic_v3_mosaics),1,'member reads joined Mosaic');
select is(jsonb_array_length(public.v3_list_mosaics()),1,'member lists joined Mosaic through the public RPC');
select is((select count(*)::int from public.mosaic_v3_kindness_contributions),1,'member reads only own contribution before reveal');
select is((select count(*)::int from public.mosaic_v3_event_photos),1,'member reads only own photo before reveal');
select is((public.v3_load_mosaic('92000000-0000-4000-8000-000000000001')->>'contributionCount')::int,2,'member sees aggregate contribution count before reveal');
select is(jsonb_array_length(public.v3_load_mosaic('92000000-0000-4000-8000-000000000001')->'occupiedTilePositions'),2,'member sees occupied tile fronts before reveal');
select is(public.v3_load_mosaic('92000000-0000-4000-8000-000000000001')->'artwork'->>'assetName','SealedArtwork','member cannot resolve selected artwork before reveal');
select isnt(public.v3_resolve_invitation('SECURE24')->'artwork'->>'id','a0000000-0000-4000-8000-000000000001','invitation preview does not disclose selected artwork');
select throws_ok($$select public.v3_release_artwork('92000000-0000-4000-8000-000000000001')$$,'42501','reveal_locked','artwork decryption material is locked before reveal');
select throws_ok($$select public.v3_complete_activity('92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001',null)$$,'23505',null,'one completion per activity is enforced');

select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*)::int from public.mosaic_v3_event_photos),0,'organizer has no special pre-reveal photo access');

select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select is((select count(*)::int from public.mosaic_v3_mosaics),0,'nonmember cannot read event content');
select throws_ok($$select public.v3_load_mosaic('92000000-0000-4000-8000-000000000001')$$,'42501','not_a_member','nonmember cannot load Mosaic');

reset role;
update public.mosaic_v3_mosaics set reveal_at=now()-interval '1 minute',revealed_at=now()-interval '1 minute' where id='92000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from public.mosaic_v3_kindness_contributions),2,'member reads all contributions after reveal');
select is((select count(*)::int from public.mosaic_v3_event_photos),2,'member reads all eligible photos after reveal');
select is(public.v3_load_mosaic('92000000-0000-4000-8000-000000000001')->'artwork'->>'assetName','OnboardingWaterLilies','selected artwork metadata releases after reveal');
select is(public.v3_release_artwork('92000000-0000-4000-8000-000000000001')->>'key','test-key','joined member receives artwork key only after reveal');
select throws_ok($$select public.v3_withdraw_contribution('94000000-0000-4000-8000-000000000001')$$,'P0001','mosaic_revealed','undo closes at reveal');
select throws_ok($$select public.v3_join_mosaic('SECURE24')$$,'P0001','joining_closed','joining closes at reveal');

select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000005","role":"authenticated"}',true);
select ok(public.v3_report_event_photo('95000000-0000-4000-8000-000000000001','Inappropriate shared photo'),'member can report revealed photo');
reset role;
select is((select state from public.mosaic_v3_event_photos where id='95000000-0000-4000-8000-000000000001'),'quarantined','report immediately quarantines photo');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from public.mosaic_v3_event_photos),1,'quarantined photo is absent from gallery query');
select ok(public.v3_block_user('91000000-0000-4000-8000-000000000003'),'member can block contributor');
select is((select count(*)::int from public.mosaic_v3_event_photos),0,'blocking filters contributor photos');
select ok(public.v3_unblock_user('91000000-0000-4000-8000-000000000003'),'member can unblock contributor');
select is((select count(*)::int from public.mosaic_v3_event_photos),1,'unblocking restores eligible contributor photos');

select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select ok(public.v3_delete_mosaic('92000000-0000-4000-8000-000000000001'),'creator may delete after reveal');
select is((select count(*)::int from public.mosaic_v3_mosaics where id='92000000-0000-4000-8000-000000000001'),0,'creator deletion cascades event');

select * from finish();
rollback;
