import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  body,
  failure,
  HttpError,
  ok,
  requiredUUID,
  userId,
} from "../_shared/mosaic.ts";

type RequestBody = { momentId: string };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const momentId = requiredUUID(input.momentId, "momentId");
      const { data, error } = await ctx.supabaseAdmin.rpc(
        "internal_withdraw_kindness_roll_moment",
        { target_moment_id: momentId, target_user_id: userId(ctx) },
      ).single();
      if (error) throw error;
      if (
        !data || typeof data !== "object" || !("action" in data) ||
        typeof data.action !== "string"
      ) {
        throw new HttpError(
          500,
          "Moment withdrawal returned an invalid result",
        );
      }
      const mediaPath = "media_path" in data &&
          typeof data.media_path === "string"
        ? data.media_path
        : null;
      if (mediaPath) {
        const { error: storageError } = await ctx.supabaseAdmin.storage
          .from("recap-memories").remove([mediaPath]);
        if (storageError) throw storageError;
      }
      return ok({ action: data.action });
    } catch (error) {
      return failure(error);
    }
  }),
};
