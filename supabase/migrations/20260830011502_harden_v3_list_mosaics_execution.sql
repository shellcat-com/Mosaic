-- Listing crosses into the locked private helper schema. Run the public RPC as
-- its owner while retaining the explicit membership predicate in the query.

create or replace function public.v3_list_mosaics()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(private.v3_summary_json(m) order by m.reveal_at),
    '[]'::jsonb
  )
  from public.mosaic_v3_mosaics as m
  where private.v3_is_mosaic_member(m.id);
$$;

revoke all on function public.v3_list_mosaics()
  from public, anon, authenticated;
grant execute on function public.v3_list_mosaics() to authenticated;
