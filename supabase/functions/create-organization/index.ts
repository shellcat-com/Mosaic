import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  body,
  failure,
  ok,
  requiredString,
  requirePermanentAccount,
} from "../_shared/mosaic.ts";

type RequestBody = { organizationName?: string; organizerDisplayName?: string };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const ownerId = requirePermanentAccount(ctx);
      const input = await body<RequestBody>(request);
      const organizationName = requiredString(
        input.organizationName,
        "organizationName",
        100,
      );
      const organizerDisplayName = requiredString(
        input.organizerDisplayName,
        "organizerDisplayName",
        60,
      );
      const { data, error } = await ctx.supabaseAdmin.rpc(
        "internal_create_organization",
        {
          owner_id: ownerId,
          organization_name: organizationName,
          organizer_display_name: organizerDisplayName,
        },
      );
      if (error) throw error;
      return ok(data, 201);
    } catch (error) {
      return failure(error);
    }
  }),
};
