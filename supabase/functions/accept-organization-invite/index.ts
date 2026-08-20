import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  body,
  failure,
  ok,
  requiredString,
  requirePermanentAccount,
} from "../_shared/mosaic.ts";

type RequestBody = { token?: string };

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
      const userId = requirePermanentAccount(ctx);
      const input = await body<RequestBody>(request);
      const token = requiredString(input.token, "token", 100);
      const { data, error } = await ctx.supabaseAdmin.rpc(
        "internal_accept_organization_invite",
        {
          accepting_user_id: userId,
          supplied_token_hash: await sha256(token),
        },
      );
      if (error) throw error;
      return ok(data);
    } catch (error) {
      return failure(error);
    }
  }),
};
