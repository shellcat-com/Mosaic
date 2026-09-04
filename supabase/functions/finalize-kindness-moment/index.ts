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
      const admin = ctx.supabaseAdmin;
      const { data: moment, error: momentError } = await admin.from(
        "shared_moments",
      )
        .select("id,creator_id,media_path,media_kind")
        .eq("id", contributionId).eq("contribution_id", contributionId)
        .single();
      if (momentError) throw momentError;
      if (moment.creator_id !== uid) {
        throw new HttpError(403, "Only the contributor can seal this moment");
      }

      if (moment.media_kind !== "note") {
        if (!moment.media_path) {
          throw new HttpError(409, "Prepared media path is missing");
        }
        const parts = moment.media_path.split("/");
        const filename = parts.pop()!;
        const folder = parts.join("/");
        const { data: objects, error: listError } = await admin.storage.from(
          "recap-memories",
        )
          .list(folder, { search: filename, limit: 1 });
        if (listError) throw listError;
        if (!objects.some((item: { name: string }) => item.name === filename)) {
          throw new HttpError(409, "Moment upload has not completed");
        }
      }

      const { data: placement, error: placementError } = await admin.rpc(
        "internal_finalize_kindness_roll_contribution",
        {
          target_contribution_id: contributionId,
          target_moment_id: contributionId,
          target_user_id: uid,
        },
      ).single();
      if (placementError) throw placementError;
      if (
        !placement || typeof placement !== "object" ||
        !("tile_position" in placement) ||
        typeof placement.tile_position !== "number"
      ) {
        throw new HttpError(500, "Tile placement returned an invalid result");
      }

      const { data: sealed, error: sealedError } = await admin.from(
        "shared_moments",
      )
        .select().eq("id", contributionId).single();
      if (sealedError) throw sealedError;
      return ok({
        contributionId,
        tilePosition: placement.tile_position,
        moment: sealed,
      });
    } catch (error) {
      return failure(error);
    }
  }),
};
