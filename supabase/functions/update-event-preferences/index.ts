import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  assertMember,
  body,
  failure,
  HttpError,
  ok,
  requiredUUID,
  userId,
} from "../_shared/mosaic.ts";

type RequestBody = {
  challengeId: string;
  challengeStart: boolean;
  revealDayBefore: boolean;
  revealHourBefore: boolean;
  revealNow: boolean;
  recapReady: boolean;
  liveActivity: boolean;
};

function requiredBoolean(value: unknown, field: string): boolean {
  if (typeof value !== "boolean") {
    throw new HttpError(400, `${field} must be a boolean`);
  }
  return value;
}

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const challengeId = requiredUUID(input.challengeId, "challengeId");
      await assertMember(ctx, challengeId);
      const uid = userId(ctx);
      const database = ctx.supabase as any;
      const admin = ctx.supabaseAdmin as any;

      const { error } = await database.from("event_notification_preferences")
        .upsert({
          challenge_id: challengeId,
          user_id: uid,
          challenge_start: requiredBoolean(
            input.challengeStart,
            "challengeStart",
          ),
          reveal_day_before: requiredBoolean(
            input.revealDayBefore,
            "revealDayBefore",
          ),
          reveal_hour_before: requiredBoolean(
            input.revealHourBefore,
            "revealHourBefore",
          ),
          reveal_now: requiredBoolean(input.revealNow, "revealNow"),
          recap_ready: requiredBoolean(input.recapReady, "recapReady"),
          live_activity: requiredBoolean(input.liveActivity, "liveActivity"),
          updated_at: new Date().toISOString(),
        }, { onConflict: "challenge_id,user_id" });
      if (error) throw error;
      if (!input.liveActivity) {
        const { error: tokenError } = await admin.from("live_activity_tokens")
          .update({ disabled_at: new Date().toISOString() })
          .eq("challenge_id", challengeId).eq("user_id", uid);
        if (tokenError) throw tokenError;
      }
      return ok({ ok: true });
    } catch (error) {
      return failure(error);
    }
  }),
};
