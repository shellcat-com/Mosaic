import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  assertOrganizationRole,
  body,
  failure,
  HttpError,
  ok,
  requiredUUID,
} from "../_shared/mosaic.ts";

type RequestBody = { organizationId?: string };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const organizationId = requiredUUID(
        input.organizationId,
        "organizationId",
      );
      await assertOrganizationRole(ctx, organizationId, ["owner"]);
      const apiKey = Deno.env.get("REVENUECAT_SECRET_API_KEY");
      const projectId = Deno.env.get("REVENUECAT_PROJECT_ID");
      if (!apiKey || !projectId) {
        throw new HttpError(
          503,
          "RevenueCat server configuration is incomplete",
        );
      }
      const { data: account, error: accountError } = await ctx.supabaseAdmin
        .from("billing_accounts")
        .select("revenuecat_customer_id").eq("organization_id", organizationId)
        .single();
      if (accountError) throw accountError;
      const response = await fetch(
        `https://api.revenuecat.com/v2/projects/${
          encodeURIComponent(projectId)
        }/customers/${encodeURIComponent(account.revenuecat_customer_id)}`,
        { headers: { Authorization: `Bearer ${apiKey}` } },
      );
      if (!response.ok) {
        throw new HttpError(502, "Unable to refresh RevenueCat customer");
      }
      const customer = await response.json();
      const currencies = customer?.virtual_currencies?.items ??
        customer?.virtual_currencies ?? [];
      const passItem = Array.isArray(currencies)
        ? currencies.find((item: Record<string, unknown>) =>
          item.code === "PASS" || item.currency_code === "PASS"
        )
        : null;
      const balance = Number(
        passItem?.balance ?? customer?.virtual_currencies?.PASS?.balance ??
          customer?.virtual_currency_balances?.PASS ?? 0,
      );
      const entitlementItems = customer?.active_entitlements?.items ??
        customer?.entitlements?.items ?? [];
      const entitlement = Array.isArray(entitlementItems)
        ? entitlementItems.find((item: Record<string, unknown>) =>
          item.id === "organizer_plus" ||
          item.entitlement_id === "organizer_plus"
        )
        : customer?.entitlements?.organizer_plus;
      const subscriptionItems = customer?.active_subscriptions?.items ??
        customer?.subscriptions?.items ?? [];
      const subscription = Array.isArray(subscriptionItems)
        ? subscriptionItems[0]
        : null;
      const expiresAt = entitlement?.expires_at ??
        subscription?.current_period_ends_at ?? null;
      const productId = subscription?.product_id ?? entitlement?.product_id ??
        null;
      const renewal = subscription?.auto_renewal_status ??
        subscription?.will_renew;
      const willRenew = renewal === true || renewal === "will_renew" ||
        renewal === "enabled";
      const { error: updateError } = await ctx.supabaseAdmin.from(
        "billing_accounts",
      ).update({
        pass_balance: Math.max(
          0,
          Number.isFinite(balance) ? Math.trunc(balance) : 0,
        ),
        subscription_status: entitlement ? "active" : "none",
        product_id: productId,
        entitlement_expires_at: expiresAt,
        will_renew: willRenew,
        last_synced_at: new Date().toISOString(),
      }).eq("organization_id", organizationId);
      if (updateError) throw updateError;
      if (entitlement) {
        const { error: challengeError } = await ctx.supabaseAdmin.from(
          "challenges",
        ).update({
          access_source: "organizer_plus",
          participant_limit: 250,
          collaborator_limit: 5,
          premium_access_until: null,
        }).eq("organization_id", organizationId).in("status", [
          "active",
          "revealed",
        ]);
        if (challengeError) throw challengeError;
      }
      const { data, error } = await ctx.supabase.rpc(
        "organization_access_snapshot",
        {
          requested_organization_id: organizationId,
        },
      );
      if (error) throw error;
      return ok(data);
    } catch (error) {
      return failure(error);
    }
  }),
};
