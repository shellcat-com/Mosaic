import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  body,
  failure,
  HttpError,
  ok,
  requiredString,
  requiredUUID,
} from "../_shared/mosaic.ts";

type RequestBody = { contributionId: string; kind: "evidence" | "memory" };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const contributionId = requiredUUID(
        input.contributionId,
        "contributionId",
      );
      const kind = requiredString(input.kind, "kind", 10);
      if (kind !== "evidence" && kind !== "memory") {
        throw new HttpError(400, "kind is invalid");
      }

      const table = kind === "evidence" ? "evidence_submissions" : "memories";
      const { data, error } = await ctx.supabase.from(table)
        .select("media_path").eq("contribution_id", contributionId)
        .maybeSingle();
      if (error) throw error;
      if (!data) {
        throw new HttpError(403, "Media is not available to this user");
      }
      if (!data.media_path) throw new HttpError(404, "This item has no media");

      const bucket = kind === "evidence"
        ? "evidence-private"
        : "recap-memories";
      const { data: signed, error: signedError } = await ctx.supabaseAdmin
        .storage
        .from(bucket).createSignedUrl(data.media_path, 300);
      if (signedError) throw signedError;
      return ok({ url: signed.signedUrl, expiresIn: 300 });
    } catch (error) {
      return failure(error);
    }
  }),
};
