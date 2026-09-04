create or replace function private.v3_can_read_artwork_package(target_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1
    from private.mosaic_v3_artwork_reveal_packages package
    join public.mosaic_v3_mosaics mosaic on mosaic.id = package.mosaic_id
    join public.mosaic_v3_members member on member.mosaic_id = mosaic.id
    where package.ciphertext_path = target_path
      and member.profile_id = auth.uid()
      and now() >= mosaic.reveal_at
  );
$$;

revoke all on function private.v3_can_read_artwork_package(text) from public, anon, authenticated;
grant execute on function private.v3_can_read_artwork_package(text) to authenticated;

drop policy if exists artwork_packages_storage_select on storage.objects;
create policy artwork_packages_storage_select on storage.objects for select to authenticated using (
  bucket_id='artwork-reveal-packages' and private.v3_can_read_artwork_package(name)
);
