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
import { recordRevealEvent } from "../_shared/reveal-package.ts";

type RequestBody = { challengeId: string };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const uid = userId(ctx);
      const startedAt = Date.now();
      const input = await body<RequestBody>(request);
      const challengeId = requiredUUID(input.challengeId, "challengeId");
      const { data: reveal, error } = await ctx.supabaseAdmin.rpc(
        "internal_release_reveal_package",
        { target_challenge_id: challengeId, target_user_id: uid },
      );
      if (error) {
        const message = error.message ?? "Artwork key is unavailable";
        const status = message.includes("membership") ? 403 : 409;
        throw new HttpError(status, message);
      }

      const { data: exportURL, error: signedError } = await ctx.supabaseAdmin
        .storage
        .from("museum-artwork-sources").createSignedUrl(reveal.exportPath, 900);
      if (signedError || !exportURL?.signedUrl) {
        throw new HttpError(
          500,
          signedError?.message ?? "Unable to sign export artwork",
        );
      }
      await recordRevealEvent(ctx, uid, challengeId, "artwork_key_released", {
        packageRevision: reveal.packageRevision,
        durationMs: Date.now() - startedAt,
      });

      return ok({
        packageRevision: reveal.packageRevision,
        checksum: reveal.checksum,
        key: reveal.key,
        nonce: reveal.nonce,
        aad: reveal.aad,
        exportURL: exportURL.signedUrl,
        exportChecksum: reveal.exportChecksum,
        artwork: reveal.artwork,
      });
    } catch (error) {
      return failure(error);
    }
  }),
};
