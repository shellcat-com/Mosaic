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

type RequestBody = { challengeId: string };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const uid = userId(ctx);
      const input = await body<RequestBody>(request);
      const challengeId = requiredUUID(input.challengeId, "challengeId");
      const { data: packageInfo, error } = await ctx.supabaseAdmin.rpc(
        "internal_prefetch_reveal_package",
        { target_challenge_id: challengeId, target_user_id: uid },
      );
      if (error) {
        const status = error.message.includes("membership") ? 403 : 409;
        throw new HttpError(status, error.message);
      }
      const { data: signed, error: signedError } = await ctx.supabaseAdmin
        .storage
        .from("museum-reveal-packages")
        .createSignedUrl(packageInfo.storagePath, 21_600);
      if (signedError || !signed?.signedUrl) {
        throw new HttpError(
          500,
          signedError?.message ?? "Unable to sign reveal package",
        );
      }
      return ok({
        ciphertextURL: signed.signedUrl,
        packageRevision: packageInfo.packageRevision,
        checksum: packageInfo.checksum,
        byteCount: packageInfo.byteCount,
      });
    } catch (error) {
      return failure(error);
    }
  }),
};
