import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { failure, ok, requirePermanentAccount } from "../_shared/mosaic.ts";
import {
  parseBillingSnapshot,
  revenueCatConfiguration,
  revenueCatRequest,
} from "../_shared/revenuecat.ts";

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (_request, ctx) => {
    try {
      const userID = requirePermanentAccount(ctx).toLowerCase();
      const { projectID, secretKey } = revenueCatConfiguration();
      const customer = `/customers/${encodeURIComponent(userID)}`;
      const [entitlements, subscriptions, currencies] = await Promise.all([
        revenueCatRequest(
          projectID,
          secretKey,
          `${customer}/active_entitlements?limit=100`,
        ),
        revenueCatRequest(
          projectID,
          secretKey,
          `${customer}/subscriptions?limit=100`,
        ),
        revenueCatRequest(
          projectID,
          secretKey,
          `${customer}/virtual_currencies?include_empty_balances=true`,
        ),
      ]);
      const snapshot = parseBillingSnapshot(
        entitlements,
        subscriptions,
        currencies,
      );
      const { error } = await ctx.supabaseAdmin.rpc(
        "v3_internal_sync_billing",
        {
          userID,
          plusActive: snapshot.plusActive,
          subscriptionState: snapshot.subscriptionState,
          productID: snapshot.productID,
          expiresAt: snapshot.expiresAt,
          willRenew: snapshot.willRenew,
          passBalance: snapshot.passBalance,
        },
      );
      if (error) throw error;
      return ok(snapshot);
    } catch (error) {
      return failure(error);
    }
  }),
};
