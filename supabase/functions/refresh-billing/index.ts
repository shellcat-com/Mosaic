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
import type {
  RevenueCatActiveEntitlement,
  RevenueCatBillingState,
  RevenueCatSubscription,
  RevenueCatVirtualCurrencyBalance,
} from "../_shared/revenuecat.ts";
import { billingState, fetchRevenueCatList } from "../_shared/revenuecat.ts";

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
      const entitlementId = Deno.env.get(
        "REVENUECAT_ORGANIZER_PLUS_ENTITLEMENT_ID",
      );
      if (!apiKey || !projectId || !entitlementId) {
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
      const customerPath = `/projects/${
        encodeURIComponent(projectId)
      }/customers/${encodeURIComponent(account.revenuecat_customer_id)}`;
      let state: RevenueCatBillingState;
      try {
        const [entitlements, subscriptions, balances] = await Promise.all([
          fetchRevenueCatList<RevenueCatActiveEntitlement>(
            apiKey,
            `${customerPath}/active_entitlements?limit=100`,
          ),
          fetchRevenueCatList<RevenueCatSubscription>(
            apiKey,
            `${customerPath}/subscriptions?limit=100`,
          ),
          fetchRevenueCatList<RevenueCatVirtualCurrencyBalance>(
            apiKey,
            `${customerPath}/virtual_currencies?include_empty_balances=true&limit=100`,
          ),
        ]);
        state = billingState(
          entitlementId,
          entitlements,
          subscriptions,
          balances,
        );
      } catch (error) {
        console.error("RevenueCat refresh failed", error);
        throw new HttpError(502, "Unable to refresh RevenueCat customer");
      }
      const { error: updateError } = await ctx.supabaseAdmin.from(
        "billing_accounts",
      ).update({
        pass_balance: state.passBalance,
        subscription_status: state.subscriptionStatus,
        product_id: state.productId,
        entitlement_expires_at: state.expiresAt,
        will_renew: state.willRenew,
        last_synced_at: new Date().toISOString(),
      }).eq("organization_id", organizationId);
      if (updateError) throw updateError;
      if (state.plusActive) {
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
