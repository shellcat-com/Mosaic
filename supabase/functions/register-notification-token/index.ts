import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  assertMember,
  body,
  failure,
  HttpError,
  ok,
  requiredString,
  requiredUUID,
  userId,
} from "../_shared/mosaic.ts";

type RequestBody = {
  token: string;
  environment?: string;
  challengeId?: string;
  activityId?: string;
};

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const uid = userId(ctx);
      const admin = ctx.supabaseAdmin as any;
      const token = requiredString(input.token, "token", 256).toLowerCase();
      if (!/^[a-f0-9]{64,256}$/.test(token)) {
        throw new HttpError(400, "token is invalid");
      }

      if (input.challengeId || input.activityId) {
        const challengeId = requiredUUID(input.challengeId, "challengeId");
        const activityId = requiredString(input.activityId, "activityId", 200);
        const environment = input.environment === "production"
          ? "production"
          : "sandbox";
        await assertMember(ctx, challengeId);
        const { error } = await admin.from("live_activity_tokens").upsert({
          user_id: uid,
          challenge_id: challengeId,
          activity_id: activityId,
          token,
          environment,
          disabled_at: null,
          last_seen_at: new Date().toISOString(),
        }, { onConflict: "user_id,activity_id" });
        if (error) throw error;
      } else {
        const environment = input.environment === "production"
          ? "production"
          : "sandbox";
        const { error } = await admin.from("notification_devices").upsert({
          user_id: uid,
          token,
          environment,
          disabled_at: null,
          last_seen_at: new Date().toISOString(),
        }, { onConflict: "token" });
        if (error) throw error;
      }
      return ok({ ok: true });
    } catch (error) {
      return failure(error);
    }
  }),
};
