import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { failure, ok, requirePermanentAccount } from "../_shared/mosaic.ts";
import {
  revenueCatConfiguration,
  revenueCatRequest,
} from "../_shared/revenuecat.ts";
import { deleteAccountData } from "./logic.ts";

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (_request, ctx) => {
    try {
      const uid = requirePermanentAccount(ctx).toLowerCase();
      const { projectID, secretKey } = revenueCatConfiguration();
      return ok(
        await deleteAccountData(uid, {
          deleteRevenueCatCustomer: async (userID) => {
            await revenueCatRequest(
              projectID,
              secretKey,
              `/customers/${encodeURIComponent(userID)}`,
              { method: "DELETE" },
            );
          },
          deleteSupabaseUser: async (userID) => {
            const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(
              userID,
            );
            if (error) throw error;
          },
        }),
      );
    } catch (error) {
      return failure(error);
    }
  }),
};
