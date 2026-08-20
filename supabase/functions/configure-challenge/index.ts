import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { publishedTheme } from "../_shared/kinder-themes.ts";
import {
  assertOrganizer,
  body,
  failure,
  HttpError,
  ok,
  requiredString,
  requiredUUID,
} from "../_shared/mosaic.ts";

type RequestBody = {
  challengeId: string;
  name: string;
  groupName: string;
  purpose: string;
  goal: number;
  startAt: string;
  revealAt: string;
  themeId: string;
  themePaletteId: string;
  themeSeed: number;
  themeRevision: number;
};

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const challengeId = requiredUUID(input.challengeId, "challengeId");
      await assertOrganizer(ctx, challengeId);

      const name = requiredString(input.name, "name", 80);
      const groupName = requiredString(input.groupName, "groupName", 80);
      const purpose = requiredString(input.purpose, "purpose", 500);
      if (
        !Number.isSafeInteger(input.goal) || input.goal < 1 ||
        input.goal > 10_000
      ) {
        throw new HttpError(400, "goal must be between 1 and 10,000");
      }
      const startAt = new Date(input.startAt);
      const revealAt = new Date(input.revealAt);
      if (
        Number.isNaN(startAt.getTime()) || Number.isNaN(revealAt.getTime()) ||
        revealAt <= startAt
      ) {
        throw new HttpError(400, "revealAt must be later than startAt");
      }
      const theme = publishedTheme(input);

      const { data: existing, error: existingError } = await ctx.supabaseAdmin
        .from("challenges")
        .select(
          "id,theme_id,theme_palette_id,theme_seed,theme_revision,schedule_revision",
        )
        .eq("id", challengeId)
        .single();
      if (existingError) {
        throw new HttpError(
          existingError.code === "PGRST116" ? 404 : 500,
          existingError.message,
        );
      }

      const { count, error: contributionError } = await ctx.supabaseAdmin.from(
        "contributions",
      )
        .select("id", { count: "exact", head: true })
        .eq("challenge_id", challengeId);
      if (contributionError) {
        throw new HttpError(500, contributionError.message);
      }
      const changesArtwork = existing.theme_id !== theme.theme_id ||
        existing.theme_palette_id !== theme.theme_palette_id ||
        existing.theme_seed !== theme.theme_seed ||
        existing.theme_revision !== theme.theme_revision;
      if ((count ?? 0) > 0 && changesArtwork) {
        throw new HttpError(
          409,
          "Artwork is locked after the first tile is placed",
        );
      }

      const { data, error } = await ctx.supabaseAdmin.from("challenges").update(
        {
          name,
          group_name: groupName,
          purpose,
          goal: input.goal,
          start_at: startAt.toISOString(),
          reveal_at: revealAt.toISOString(),
          ...theme,
          schedule_revision: (existing.schedule_revision ?? 0) + 1,
          updated_at: new Date().toISOString(),
        },
      ).eq("id", challengeId)
        .select(
          "id,name,group_name,purpose,goal,start_at,reveal_at,revealed_at,status,schedule_revision,featured_recap_export_id,invitation_code,is_showcase,camera_roll_enabled,theme_id,theme_palette_id,theme_seed,theme_revision",
        )
        .single();
      if (error) throw new HttpError(500, error.message);
      return ok({ challenge: data });
    } catch (error) {
      return failure(error);
    }
  }),
};
