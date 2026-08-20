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

type RequestBody = { organizationId?: string; newOwnerId?: string };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const organizationId = requiredUUID(
        input.organizationId,
        "organizationId",
      );
      const newOwnerId = requiredUUID(input.newOwnerId, "newOwnerId");
      await assertOrganizationRole(ctx, organizationId, ["owner"]);
      const { error } = await ctx.supabaseAdmin.rpc(
        "internal_transfer_organization_ownership",
        {
          target_organization_id: organizationId,
          current_owner_id: userId(ctx),
          new_owner_id: newOwnerId,
        },
      );
      if (error) throw error;
      return ok({ transferred: true });
    } catch (error) {
      return failure(error);
    }
  }),
};
