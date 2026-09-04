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

      const { data: existing, error: existingError } = await ctx.supabaseAdmin
        .from("challenges").select("status,artwork_mode").eq("id", challengeId)
        .single();
      if (existingError) throw new HttpError(500, existingError.message);

      let revealAt = new Date().toISOString();
      let status = "revealed";
      if (
        input.revealNow && existing.artwork_mode === "museum" &&
        !["awaiting_reveal", "revealed"].includes(existing.status)
      ) {
        throw new HttpError(409, "The museum board must be full before reveal");
      }
      if (!input.revealNow) {
        const parsed = new Date(input.revealAt ?? "");
        if (Number.isNaN(parsed.getTime()) || parsed.getTime() <= Date.now()) {
          throw new HttpError(400, "revealAt must be a future timestamp");
        }
        revealAt = parsed.toISOString();
        status = existing.status;
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
          "id,organization_id,name,group_name,purpose,goal,start_at,reveal_at,revealed_at,status,schedule_revision,featured_recap_export_id,invitation_code,is_showcase,camera_roll_enabled,theme_id,theme_palette_id,theme_seed,theme_revision,artwork_mode,board_side,artwork_collection,artwork_palette,artwork_catalog_revision,artwork_package_revision,artwork_locked_at",
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
