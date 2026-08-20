import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  allowedPrivacy,
  body,
  failure,
  HttpError,
  isAnonymousUser,
  ok,
  optionalString,
  requiredString,
  userId,
} from "../_shared/mosaic.ts";

type RequestBody = { code: string; displayName: string; privacy: string };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const uid = userId(ctx);
      const input = await body<RequestBody>(request);
      const code = requiredString(input.code, "code", 12).toUpperCase();
      const displayName =
        optionalString(input.displayName, "displayName", 60) ??
          "Guest participant";
      if (!allowedPrivacy.has(input.privacy)) {
        throw new HttpError(400, "privacy is invalid");
      }

      const { data: challenge, error } = await ctx.supabaseAdmin.rpc(
        "internal_join_challenge",
        {
          joining_user_id: uid,
          challenge_code: code,
          participant_display_name: displayName,
          participant_privacy: input.privacy,
          participant_is_anonymous: isAnonymousUser(ctx),
        },
      );
      if (error) {
        if (error.message?.includes("not found")) {
          throw new HttpError(404, "Challenge code not found");
        }
        if (error.message?.includes("limit")) {
          throw new HttpError(
            409,
            "This Mosaic has reached its participant limit",
          );
        }
        throw error;
      }

      return ok({ challenge });
    } catch (error) {
      return failure(error);
    }
  }),
};
