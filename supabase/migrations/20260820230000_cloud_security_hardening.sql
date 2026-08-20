-- Supabase's project-level automatic-RLS trigger calls this function as the
-- event-trigger owner. Data API roles never need direct EXECUTE permission.
revoke all on function public.rls_auto_enable() from public, anon, authenticated;

-- These tables are intentionally service-role only. Keeping RLS with no
-- client policy is the fail-closed design for dormant billing/push delivery.
revoke all on table
  public.billing_events,
  public.live_activity_tokens,
  public.notification_deliveries,
  public.notification_devices,
  public.organization_invites,
  public.pass_redemptions
from anon, authenticated;
