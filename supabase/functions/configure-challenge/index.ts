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
  userId,
} from "../_shared/mosaic.ts";
import {
  buildRevealPackage,
  recordRevealEvent,
  type RevealPackage,
} from "../_shared/reveal-package.ts";

type RequestBody = {
  challengeId: string;
  name: string;
  groupName: string;
  purpose: string;
  goal?: number;
  startAt: string;
  revealAt: string;
  artworkId?: string;
  boardSide?: number;
  themeId?: string;
  themePaletteId?: string;
  themeSeed?: number;
  themeRevision?: number;
  experienceVersion?: number;
  filmLookId?: "sunwashed" | "garden" | "afterglow";
};

const challengeColumns =
  "id,organization_id,name,group_name,purpose,goal,start_at,reveal_at,revealed_at,status,schedule_revision,featured_recap_export_id,invitation_code,is_showcase,camera_roll_enabled,theme_id,theme_palette_id,theme_seed,theme_revision,artwork_mode,board_side,artwork_collection,artwork_palette,artwork_catalog_revision,artwork_package_revision,artwork_locked_at,experience_version,film_look_id";

function dates(input: RequestBody): { startAt: Date; revealAt: Date } {
  const startAt = new Date(input.startAt);
  const revealAt = new Date(input.revealAt);
  if (
    Number.isNaN(startAt.getTime()) || Number.isNaN(revealAt.getTime()) ||
    revealAt <= startAt
  ) {
    throw new HttpError(400, "revealAt must be later than startAt");
  }
  return { startAt, revealAt };
}

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const challengeId = requiredUUID(input.challengeId, "challengeId");
      await assertOrganizer(ctx, challengeId);
      const name = requiredString(input.name, "name", 80);
      const groupName = requiredString(input.groupName, "groupName", 80);
      const purpose = requiredString(input.purpose, "purpose", 500);
      const { startAt, revealAt } = dates(input);
      const experienceVersion = input.experienceVersion ?? 1;
      if (experienceVersion !== 1 && experienceVersion !== 2) {
        throw new HttpError(400, "experienceVersion must be 1 or 2");
      }
      const filmLookId = input.filmLookId ?? "sunwashed";
      if (!new Set(["sunwashed", "garden", "afterglow"]).has(filmLookId)) {
        throw new HttpError(400, "filmLookId is invalid");
      }

      const { data: existing, error: existingError } = await ctx.supabaseAdmin
        .from("challenges")
        .select(
          "id,artwork_mode,board_side,artwork_package_revision,theme_id,theme_palette_id,theme_seed,theme_revision,schedule_revision,experience_version,film_look_id",
        )
        .eq("id", challengeId)
        .single();
      if (existingError) {
        throw new HttpError(
          existingError.code === "PGRST116" ? 404 : 500,
          existingError.message,
        );
      }
      const { count, error: contributionError } = await ctx.supabaseAdmin
        .from("contributions").select("id", { count: "exact", head: true })
        .eq("challenge_id", challengeId)
        .in("status", ["self_attested", "verified", "placed", "revealed"]);
      if (contributionError) {
        throw new HttpError(500, contributionError.message);
      }
      if ((count ?? 0) > 0 && existing.film_look_id !== filmLookId) {
        throw new HttpError(
          409,
          "The film look is locked after the first sealed contribution",
        );
      }
      if (
        (count ?? 0) > 0 && existing.experience_version !== experienceVersion
      ) {
        throw new HttpError(
          409,
          "The group experience cannot change after participation begins",
        );
      }

      if (input.artworkId != null || input.boardSide != null) {
        const artworkId = requiredUUID(input.artworkId, "artworkId");
        const boardSideValue = input.boardSide;
        if (
          typeof boardSideValue !== "number" ||
          !Number.isSafeInteger(boardSideValue) || boardSideValue < 3 ||
          boardSideValue > 10
        ) {
          throw new HttpError(
            400,
            "boardSide must be an integer from 3 through 10",
          );
        }
        const boardSide = boardSideValue;

        const [
          { data: flag, error: flagError },
          { data: artwork, error: artworkError },
        ] = await Promise.all([
          ctx.supabaseAdmin.from("feature_flags").select(
            "enabled,rollout_percent",
          )
            .eq("key", "museum_art_creation").maybeSingle(),
          ctx.supabaseAdmin.from("artwork_catalog").select(
            "id,catalog_revision",
          )
            .eq("id", artworkId).eq("active", true).eq("is_public_domain", true)
            .maybeSingle(),
        ]);
        if (flagError || artworkError) {
          throw new HttpError(
            500,
            flagError?.message ?? artworkError?.message ??
              "Unable to load the artwork catalog",
          );
        }
        if (!flag?.enabled || (flag.rollout_percent ?? 0) <= 0) {
          throw new HttpError(
            409,
            "Museum artwork creation is not enabled yet",
          );
        }
        if (!artwork) throw new HttpError(404, "Artwork not found");

        const packageRevision = (existing.artwork_package_revision ?? 0) + 1;
        const packageStartedAt = Date.now();
        let revealPackage: RevealPackage;
        try {
          revealPackage = await buildRevealPackage(
            ctx,
            challengeId,
            artwork.id,
            artwork.catalog_revision,
            packageRevision,
          );
        } catch (error) {
          await recordRevealEvent(
            ctx,
            userId(ctx),
            challengeId,
            "artwork_package_failed",
            {
              packageRevision,
              durationMs: Date.now() - packageStartedAt,
            },
          );
          throw error;
        }
        const { error: commitError } = await ctx.supabaseAdmin.rpc(
          "internal_commit_museum_challenge",
          {
            target_challenge_id: challengeId,
            target_artwork_id: artwork.id,
            target_board_side: boardSide,
            target_name: name,
            target_group_name: groupName,
            target_purpose: purpose,
            target_start_at: startAt.toISOString(),
            target_reveal_at: revealAt.toISOString(),
            target_package_revision: revealPackage.packageRevision,
            target_package_path: revealPackage.storagePath,
            target_key_base64: revealPackage.key,
            target_nonce_base64: revealPackage.nonce,
            target_aad: revealPackage.aad,
            target_checksum: revealPackage.checksum,
            target_byte_count: revealPackage.byteCount,
          },
        );
        if (commitError) {
          await ctx.supabaseAdmin.storage.from("museum-reveal-packages")
            .remove([revealPackage.storagePath]);
          const status = commitError.message.includes("locked") ? 409 : 500;
          throw new HttpError(status, commitError.message);
        }
        await recordRevealEvent(
          ctx,
          userId(ctx),
          challengeId,
          "artwork_package_generated",
          {
            packageRevision,
            durationMs: Date.now() - packageStartedAt,
            byteCount: revealPackage.byteCount,
          },
        );
        const { data: challenge, error: versionError } = await ctx.supabaseAdmin
          .from("challenges").update({
            experience_version: experienceVersion,
            film_look_id: filmLookId,
            goal: boardSide * boardSide,
            updated_at: new Date().toISOString(),
          }).eq("id", challengeId).select(challengeColumns).single();
        if (versionError) throw new HttpError(500, versionError.message);
        return ok({ challenge });
      }

      if (existing.artwork_mode === "museum") {
        throw new HttpError(
          409,
          "This Mosaic uses museum artwork and needs an updated client",
        );
      }
      const goalValue = input.goal;
      if (
        typeof goalValue !== "number" || !Number.isSafeInteger(goalValue) ||
        goalValue < 1 || goalValue > 10_000
      ) {
        throw new HttpError(400, "goal must be between 1 and 10,000");
      }
      const goal = goalValue;
      const theme = publishedTheme(input as Required<RequestBody>);
      const changesArtwork = existing.theme_id !== theme.theme_id ||
        existing.theme_palette_id !== theme.theme_palette_id ||
        existing.theme_seed !== theme.theme_seed ||
        existing.theme_revision !== theme.theme_revision;
      if ((count ?? 0) > 0 && changesArtwork) {
        throw new HttpError(
          409,
          "Artwork is locked after the first accepted tile",
        );
      }

      const { data, error } = await ctx.supabaseAdmin.from("challenges").update(
        {
          name,
          group_name: groupName,
          purpose,
          goal,
          start_at: startAt.toISOString(),
          reveal_at: revealAt.toISOString(),
          experience_version: experienceVersion,
          film_look_id: filmLookId,
          ...theme,
          schedule_revision: (existing.schedule_revision ?? 0) + 1,
          updated_at: new Date().toISOString(),
        },
      ).eq("id", challengeId).select(challengeColumns).single();
      if (error) throw new HttpError(500, error.message);
      return ok({ challenge: data });
    } catch (error) {
      return failure(error);
    }
  }),
};
