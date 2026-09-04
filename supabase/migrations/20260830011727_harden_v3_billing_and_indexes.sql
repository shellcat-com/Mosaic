-- New functions receive EXECUTE for PUBLIC unless explicitly revoked.
-- Billing snapshots are account-scoped and must never be callable anonymously.
revoke all on function public.v3_billing_snapshot()
  from public, anon, authenticated;
grant execute on function public.v3_billing_snapshot() to authenticated;

-- Cover every V3 foreign-key lookup used during cascades and common
-- membership/ownership queries. Existing unique indexes already cover the
-- remaining foreign keys whose referenced column is the leading key.
create index mosaic_v3_mosaics_creator_idx
  on public.mosaic_v3_mosaics(creator_id);
create index mosaic_v3_mosaics_artwork_idx
  on public.mosaic_v3_mosaics(artwork_id);
create index mosaic_v3_members_profile_idx
  on public.mosaic_v3_members(profile_id);
create index mosaic_v3_contributions_activity_mosaic_idx
  on public.mosaic_v3_kindness_contributions(activity_id, mosaic_id);
create index mosaic_v3_contributions_participant_idx
  on public.mosaic_v3_kindness_contributions(participant_id);
create index mosaic_v3_event_photos_mosaic_idx
  on public.mosaic_v3_event_photos(mosaic_id);
create index mosaic_v3_event_photos_photographer_idx
  on public.mosaic_v3_event_photos(photographer_id);
create index mosaic_v3_event_photo_reports_reporter_idx
  on public.mosaic_v3_event_photo_reports(reporter_id);
create index mosaic_v3_user_blocks_blocked_idx
  on public.mosaic_v3_user_blocks(blocked_id);
