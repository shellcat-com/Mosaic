import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  body,
  failure,
  HttpError,
  ok,
  requiredString,
} from "../_shared/mosaic.ts";

type RequestBody = { guestAccessToken?: string; targetAccessToken?: string };

export default {
  fetch: withSupabase<any>({ auth: "none" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const guestToken = requiredString(
        input.guestAccessToken,
        "guestAccessToken",
        4096,
      );
      const targetToken = requiredString(
        input.targetAccessToken,
        "targetAccessToken",
        4096,
      );
      const [{ data: guestData }, { data: targetData }] = await Promise.all([
        ctx.supabaseAdmin.auth.getUser(guestToken),
        ctx.supabaseAdmin.auth.getUser(targetToken),
      ]);
      const guest = guestData?.user;
      const target = targetData?.user;
      if (!guest || !target) {
        throw new HttpError(401, "Both authenticated sessions are required");
      }
      if (guest.is_anonymous !== true || target.is_anonymous === true) {
        throw new HttpError(403, "Invalid merge accounts");
      }
      const { error } = await ctx.supabaseAdmin.rpc(
        "internal_merge_guest_account",
        {
          guest_user_id: guest.id,
          target_user_id: target.id,
        },
      );
      if (error) throw error;
      await ctx.supabaseAdmin.auth.admin.deleteUser(guest.id);
      return ok({ merged: true, userId: target.id });
    } catch (error) {
      return failure(error);
    }
  }),
};
