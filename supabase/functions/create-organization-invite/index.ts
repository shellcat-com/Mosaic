import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  assertOrganizationRole,
  body,
  failure,
  HttpError,
  ok,
  requiredString,
  requiredUUID,
  userId,
} from "../_shared/mosaic.ts";

type RequestBody = { organizationId?: string; role?: string };

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)].map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const organizationId = requiredUUID(
        input.organizationId,
        "organizationId",
      );
      const role = requiredString(input.role, "role", 20);
      if (role !== "admin" && role !== "reviewer") {
        throw new HttpError(400, "role must be admin or reviewer");
      }
      await assertOrganizationRole(ctx, organizationId, ["owner"]);

      const bytes = crypto.getRandomValues(new Uint8Array(32));
      const token = btoa(String.fromCharCode(...bytes)).replaceAll("+", "-")
        .replaceAll("/", "_").replaceAll("=", "");
      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
      const { data, error } = await ctx.supabaseAdmin.from(
        "organization_invites",
      ).insert({
        organization_id: organizationId,
        role,
        token_hash: await sha256(token),
        created_by: userId(ctx),
        expires_at: expiresAt.toISOString(),
      }).select("id,organization_id,role,expires_at").single();
      if (error) throw error;
      return ok({ ...data, url: `mosaic://workspace-invite/${token}` }, 201);
    } catch (error) {
      return failure(error);
    }
  }),
};
