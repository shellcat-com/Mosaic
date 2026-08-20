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

type RequestBody = { contributionId: string };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const uid = userId(ctx);
      const input = await body<RequestBody>(request);
      const contributionId = requiredUUID(
        input.contributionId,
        "contributionId",
      );
      const { data, error } = await ctx.supabaseAdmin.rpc(
        "internal_place_tile",
        {
          target_contribution_id: contributionId,
          target_user_id: uid,
        },
      );
      if (error) {
        if (
          error.message.includes("not ready") ||
          error.message.includes("not owned")
        ) {
          throw new HttpError(409, error.message);
        }
        throw error;
      }
      return ok({ contribution: data });
    } catch (error) {
      return failure(error);
    }
  }),
};
