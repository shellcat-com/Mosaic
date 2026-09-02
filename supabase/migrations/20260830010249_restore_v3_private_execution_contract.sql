-- The V3 billing migration intentionally revokes direct access to its private
-- billing helpers, but its schema-wide revoke also removed the four grants
-- required by V3 RLS policies and the security-invoker list RPC.
-- Restore only that narrow execution contract; all other private helpers stay
-- inaccessible to client roles.

grant execute on function private.v3_is_mosaic_member(uuid, uuid) to authenticated;
grant execute on function private.v3_is_mosaic_creator(uuid, uuid) to authenticated;
grant execute on function private.v3_mosaic_revealed(uuid) to authenticated;
grant execute on function private.v3_summary_json(public.mosaic_v3_mosaics) to authenticated;
