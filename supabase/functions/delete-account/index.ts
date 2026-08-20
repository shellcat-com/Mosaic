import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  failure,
  HttpError,
  ok,
  requirePermanentAccount,
} from "../_shared/mosaic.ts";

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      if (request.method !== "POST") throw new HttpError(405, "POST required");
      const uid = requirePermanentAccount(ctx);
      const { count, error } = await ctx.supabaseAdmin.from(
        "organization_members",
      )
        .select("organization_id", { count: "exact", head: true })
        .eq("user_id", uid).eq("role", "owner");
      if (error) throw error;
      if ((count ?? 0) > 0) {
        throw new HttpError(
          409,
          "Transfer ownership or delete each workspace before deleting your account",
        );
      }
      const { error: deleteError } = await ctx.supabaseAdmin.auth.admin
        .deleteUser(uid);
      if (deleteError) throw deleteError;
      return ok({ deleted: true });
    } catch (error) {
      return failure(error);
    }
  }),
};
