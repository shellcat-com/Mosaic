create index if not exists mosaic_v3_pass_redemptions_user_idx
  on private.mosaic_v3_pass_redemptions(user_id);

create index if not exists mosaic_v3_pass_redemptions_mosaic_idx
  on private.mosaic_v3_pass_redemptions(mosaic_id)
  where mosaic_id is not null;
