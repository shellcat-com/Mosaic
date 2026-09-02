begin;
select plan(23);

insert into auth.users(id,email,raw_user_meta_data) values
  ('96000000-0000-4000-8000-000000000001','operations-v3@mosaic.test','{}');
insert into public.mosaic_v3_profiles(id,display_name) values
  ('96000000-0000-4000-8000-000000000001','Operations Member');
insert into public.mosaic_v3_mosaics(
  id,creator_id,name,community_name,description,invitation_code,artwork_id,
  film_look_id,shot_limit,tile_goal,start_at,reveal_at
) values (
  '97000000-0000-4000-8000-000000000001','96000000-0000-4000-8000-000000000001',
  'Operations Mosaic','Test Community','Atomic behavior test','OPERATE3',
  'a0000000-0000-4000-8000-000000000001','garden',12,9,
  now()-interval '1 hour',now()+interval '1 day'
);
insert into public.mosaic_v3_members(mosaic_id,profile_id,role) values
  ('97000000-0000-4000-8000-000000000001','96000000-0000-4000-8000-000000000001','creator');
insert into public.mosaic_v3_kindness_activities(id,mosaic_id,title,purpose,sort_order)
select
  ('98000000-0000-4000-8000-' || lpad(g::text,12,'0'))::uuid,
  '97000000-0000-4000-8000-000000000001'::uuid,
  'Activity ' || g,
  'Purpose ' || g,
  g-1
from generate_series(1,10) g;

select ok(
  public.v3_pending_artwork_packages() @> '[{"mosaicID":"97000000-0000-4000-8000-000000000001"}]'::jsonb,
  'new Mosaic is queued for artwork package generation'
);
select ok(public.v3_register_artwork_package(
  '97000000-0000-4000-8000-000000000001',
  '97000000-0000-4000-8000-000000000001/artwork.aesgcm',
  repeat('a',64),
  repeat('k',44),
  repeat('n',16)
),'service package registration records encryption material');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"96000000-0000-4000-8000-000000000001","role":"authenticated"}',true);

select is(
  public.v3_complete_activity(
    '97000000-0000-4000-8000-000000000001',
    '98000000-0000-4000-8000-000000000001',
    'First note'
  )->>'note',
  'First note',
  'completion stores the optional note'
);
select is(
  public.v3_update_contribution(
    (select id from public.mosaic_v3_kindness_contributions where activity_id='98000000-0000-4000-8000-000000000001'),
    'Edited note'
  )->>'note',
  'Edited note',
  'note can be edited before reveal'
);
select ok(
  public.v3_withdraw_contribution(
    (select id from public.mosaic_v3_kindness_contributions where activity_id='98000000-0000-4000-8000-000000000001')
  ),
  'contribution can be withdrawn before reveal'
);
select is((select count(*)::int from public.mosaic_v3_kindness_contributions),0,'withdrawal releases its board position');

select public.v3_complete_activity(
  '97000000-0000-4000-8000-000000000001',id,null
)
from public.mosaic_v3_kindness_activities
order by sort_order
limit 9;
select is((select count(*)::int from public.mosaic_v3_kindness_contributions),9,'nine atomic claims fill a nine-tile board');
select is((select count(distinct tile_position)::int from public.mosaic_v3_kindness_contributions),9,'every claimed tile position is unique');
select ok((select min(tile_position)=0 and max(tile_position)=8 from public.mosaic_v3_kindness_contributions),'claimed positions stay inside board capacity');
select throws_ok(
  $$select public.v3_complete_activity('97000000-0000-4000-8000-000000000001','98000000-0000-4000-8000-000000000010',null)$$,
  'P0001','board_full','an additional claim is rejected when capacity is full'
);

select throws_ok(
  $$select public.v3_prepare_event_photo('97000000-0000-4000-8000-000000000001',gen_random_uuid(),'image/png',1000,100,100)$$,
  'P0001','invalid_photo','photo preparation rejects non-JPEG media'
);
select public.v3_prepare_event_photo(
  '97000000-0000-4000-8000-000000000001',
  ('99000000-0000-4000-8000-' || lpad(g::text,12,'0'))::uuid,
  'image/jpeg',1000,100,100
) from generate_series(1,12) g;
select is(
  public.v3_prepare_event_photo(
    '97000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000001','image/jpeg',1000,100,100
  )->>'photoID',
  '99000000-0000-4000-8000-000000000001',
  'retrying preparation for the same photo is idempotent'
);
select is(
  (select count(*)::int from public.mosaic_v3_event_photos where state='upload_pending'),
  12,
  'photographer can read own upload-pending reservations for storage authorization'
);
reset role;
select is((select count(*)::int from public.mosaic_v3_event_photos),12,'twelve prepared photos consume all twelve shots');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"96000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok(
  $$select public.v3_prepare_event_photo('97000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000013','image/jpeg',1000,100,100)$$,
  'P0001','shot_limit_reached','the thirteenth kept photo is rejected'
);
select ok(public.v3_delete_event_photo('99000000-0000-4000-8000-000000000001'),'an active-event photo can be deleted');
reset role;
select is((select count(*)::int from public.mosaic_v3_event_photos),11,'active deletion restores one shot');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"96000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select ok(
  (public.v3_prepare_event_photo(
    '97000000-0000-4000-8000-000000000001','99000000-0000-4000-8000-000000000013','image/jpeg',1000,100,100
  )->>'photoID') is not null,
  'a replacement photo can use the restored shot'
);
reset role;
select is((select count(*)::int from public.mosaic_v3_event_photos),12,'replacement returns the ledger to its shot limit');
insert into storage.objects(bucket_id,name,owner_id)
select 'event-photos',storage_path,photographer_id from public.mosaic_v3_event_photos
where id='99000000-0000-4000-8000-000000000013';

insert into public.mosaic_v3_event_photos(
  id,mosaic_id,photographer_id,storage_path,mime_type,byte_count,pixel_width,pixel_height,film_look_id,captured_at,state
) values (
  '99000000-0000-4000-8000-000000000014','97000000-0000-4000-8000-000000000001',
  '96000000-0000-4000-8000-000000000001',
  '97000000-0000-4000-8000-000000000001/96000000-0000-4000-8000-000000000001/99000000-0000-4000-8000-000000000014.jpg',
  'image/jpeg',1000,100,100,'garden',now(),'eligible'
);
insert into storage.objects(bucket_id,name,owner_id) values (
  'event-photos',
  '97000000-0000-4000-8000-000000000001/96000000-0000-4000-8000-000000000001/99000000-0000-4000-8000-000000000014.jpg',
  '96000000-0000-4000-8000-000000000001'
);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"96000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is(
  (
    select count(*)::int from storage.objects
    where bucket_id='event-photos'
      and name like '%/99000000-0000-4000-8000-000000000014.jpg'
  ),
  1,
  'authenticated event-photo reads do not evaluate private artwork-package data'
);
reset role;

update public.mosaic_v3_mosaics
set reveal_at=now()-interval '1 minute', revealed_at=null
where id='97000000-0000-4000-8000-000000000001';
select is(private.v3_mark_due_mosaics_revealed(),1,'scheduled processing marks a due Mosaic revealed');
select ok((select revealed_at is not null from public.mosaic_v3_mosaics where id='97000000-0000-4000-8000-000000000001'),'the fixed reveal timestamp is persisted');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"96000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok(
  $$select public.v3_finalize_event_photo('99000000-0000-4000-8000-000000000013')$$,
  'P0001','photography_closed','a pre-reveal reservation cannot finalize after reveal'
);

select * from finish();
rollback;
