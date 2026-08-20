import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  assertOrganizationRole,
  body,
  failure,
  ok,
  requiredUUID,
  userId,
} from "../_shared/mosaic.ts";

type RequestBody = { organizationId?: string };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const organizationId = requiredUUID(
        input.organizationId,
        "organizationId",
      );
      await assertOrganizationRole(ctx, organizationId, ["owner"]);
      const { error } = await ctx.supabaseAdmin.rpc(
        "internal_delete_organization",
        {
          target_organization_id: organizationId,
          requesting_owner_id: userId(ctx),
        },
      );
      if (error) throw error;
      return ok({ deleted: true });
    } catch (error) {
      return failure(error);
    }
  }),
};
