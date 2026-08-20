import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  assertOrganizer,
  body,
  failure,
  HttpError,
  ok,
  requiredUUID,
} from "../_shared/mosaic.ts";

type RequestBody = {
  challengeId: string;
  revealNow?: boolean;
  revealAt?: string;
};

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const challengeId = requiredUUID(input.challengeId, "challengeId");
      await assertOrganizer(ctx, challengeId);

      let revealAt = new Date().toISOString();
      let status = "revealed";
      if (!input.revealNow) {
        const parsed = new Date(input.revealAt ?? "");
        if (Number.isNaN(parsed.getTime()) || parsed.getTime() <= Date.now()) {
          throw new HttpError(400, "revealAt must be a future timestamp");
        }
        revealAt = parsed.toISOString();
        status = "active";
      }

      const { data, error } = await ctx.supabaseAdmin.from("challenges").update(
        {
          reveal_at: revealAt,
          revealed_at: status === "revealed" ? new Date().toISOString() : null,
          status,
          updated_at: new Date().toISOString(),
        },
      ).eq("id", challengeId)
        .select(
          "id,name,group_name,purpose,goal,start_at,reveal_at,revealed_at,status,schedule_revision,featured_recap_export_id,invitation_code,is_showcase,camera_roll_enabled",
        ).single();
      if (error) throw error;
      if (status === "revealed") {
        const { error: contributionError } = await ctx.supabaseAdmin.from(
          "contributions",
        ).update({
          status: "revealed",
          updated_at: new Date().toISOString(),
        }).eq("challenge_id", challengeId).eq("status", "placed");
        if (contributionError) throw contributionError;
      }
      return ok({ challenge: data });
    } catch (error) {
      return failure(error);
    }
  }),
};
