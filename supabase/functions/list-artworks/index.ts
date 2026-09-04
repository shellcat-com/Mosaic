import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  body,
  failure,
  HttpError,
  ok,
  optionalString,
  requirePermanentAccount,
} from "../_shared/mosaic.ts";

type RequestBody = { collection?: string; search?: string };

async function assertCatalogOrganizer(ctx: any): Promise<string> {
  const uid = requirePermanentAccount(ctx);
  const [
    { data: challengeRole, error: challengeError },
    { data: organizationRole, error: organizationError },
  ] = await Promise.all([
    ctx.supabaseAdmin.from("challenge_members").select("challenge_id")
      .eq("user_id", uid).eq("role", "organizer").limit(1).maybeSingle(),
    ctx.supabaseAdmin.from("organization_members").select("organization_id")
      .eq("user_id", uid).in("role", ["owner", "admin"]).limit(1).maybeSingle(),
  ]);
  if (challengeError || organizationError) {
    throw new HttpError(
      500,
      challengeError?.message ?? organizationError.message,
    );
  }
  if (!challengeRole && !organizationRole) {
    throw new HttpError(403, "Organizer access required");
  }
  return uid;
}

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      await assertCatalogOrganizer(ctx);
      const input = await body<RequestBody>(request);
      const collection = optionalString(input.collection, "collection", 32);
      const search = optionalString(input.search, "search", 80);

      let query = ctx.supabaseAdmin.from("artwork_catalog").select(
        "id,title,artist_display,date_display,source_url,alt_text,collection,dominant_colors,source_width,source_height,crop_x,crop_y,crop_width,crop_height,license_label,catalog_revision,museum_artwork_id",
      ).eq("active", true).eq("is_public_domain", true).order("title");
      if (collection) query = query.eq("collection", collection);
      if (search) query = query.ilike("title", `%${search}%`);

      const [{ data: artworks, error }, { data: flag, error: flagError }] =
        await Promise.all([
          query,
          ctx.supabaseAdmin.from("feature_flags").select(
            "enabled,rollout_percent",
          )
            .eq("key", "museum_art_creation").maybeSingle(),
        ]);
      if (error || flagError) {
        throw new HttpError(
          500,
          error?.message ?? flagError?.message ??
            "Unable to load the artwork catalog",
        );
      }

      const results = await Promise.all(
        (artworks ?? []).map(async (artwork: any) => {
          const { data: signed, error: signedError } = await ctx.supabaseAdmin
            .storage
            .from("museum-artwork-sources")
            .createSignedUrl(`${artwork.museum_artwork_id}/843.jpg`, 3_600);
          return {
            id: artwork.id,
            title: artwork.title,
            artistDisplay: artwork.artist_display,
            dateDisplay: artwork.date_display,
            sourceURL: artwork.source_url,
            altText: artwork.alt_text,
            collection: artwork.collection,
            dominantColors: artwork.dominant_colors,
            thumbnailURL: signedError ? null : signed?.signedUrl ?? null,
            licenseLabel: artwork.license_label,
            catalogRevision: artwork.catalog_revision,
            sourceWidth: artwork.source_width,
            sourceHeight: artwork.source_height,
            crop: {
              x: Number(artwork.crop_x),
              y: Number(artwork.crop_y),
              width: Number(artwork.crop_width),
              height: Number(artwork.crop_height),
            },
          };
        }),
      );

      return ok({
        enabled: flag?.enabled === true && (flag?.rollout_percent ?? 0) > 0,
        artworks: results,
      });
    } catch (error) {
      return failure(error);
    }
  }),
};
