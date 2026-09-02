-- Storage INSERT policies execute as the authenticated uploader. The original
-- photo SELECT boundary hid upload_pending reservations, which made the
-- storage policy's existence check return false and rejected every JPEG.
-- Expose only a photographer's own pending reservation metadata; files remain
-- private because the storage SELECT policy still requires state = eligible.

drop policy if exists photos_read_boundary on public.mosaic_v3_event_photos;
create policy photos_read_boundary
on public.mosaic_v3_event_photos
for select
to authenticated
using (
  private.v3_is_mosaic_member(mosaic_id)
  and (
    (photographer_id = (select auth.uid()) and state in ('upload_pending', 'eligible'))
    or (state = 'eligible' and private.v3_mosaic_revealed(mosaic_id))
  )
  and not exists (
    select 1
    from public.mosaic_v3_user_blocks b
    where b.blocker_id = (select auth.uid())
      and b.blocked_id = photographer_id
  )
);
