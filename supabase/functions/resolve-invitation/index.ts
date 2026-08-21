import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  body,
  failure,
  HttpError,
  ok,
  requiredString,
  userId,
} from "../_shared/mosaic.ts";

type RequestBody = { code: string };

const fallbackTheme = {
  themeID: "neighborhood-quilt",
  paletteID: "signature",
  seed: 1_636_670_815,
  revision: 1,
};

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      userId(ctx);
      const input = await body<RequestBody>(request);
      const code = requiredString(input.code, "code", 12).toUpperCase();
      if (!/^[A-Z0-9]+$/.test(code)) {
        throw new HttpError(400, "code is invalid");
      }

      // The invitation code is a capability. This privileged read returns only
      // the small preview contract and never creates membership or exposes
      // evidence, identities, organization records, or private activity.
      const { data: challenge, error } = await ctx.supabaseAdmin
        .from("challenges")
        .select(
          "id,name,group_name,purpose,goal,start_at,reveal_at,status,theme_id,theme_palette_id,theme_seed,theme_revision",
        )
        .eq("invitation_code", code)
        .maybeSingle();
      if (error) throw error;
      if (!challenge) throw new HttpError(404, "Challenge code not found");

      return ok({
        invitation: {
          challenge_id: challenge.id,
          code,
          name: challenge.name,
          group_name: challenge.group_name ?? "Mosaic Community",
          purpose: challenge.purpose,
          goal: challenge.goal,
          start_at: challenge.start_at,
          reveal_at: challenge.reveal_at,
          status: challenge.status,
          theme: challenge.theme_id
            ? {
              themeID: challenge.theme_id,
              paletteID: challenge.theme_palette_id ?? "signature",
              seed: challenge.theme_seed ?? fallbackTheme.seed,
              revision: challenge.theme_revision ?? fallbackTheme.revision,
            }
            : fallbackTheme,
        },
      });
    } catch (error) {
      return failure(error);
    }
  }),
};
