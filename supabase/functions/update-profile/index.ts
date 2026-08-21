import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  body,
  failure,
  ok,
  requiredString,
  userId,
} from "../_shared/mosaic.ts";

type RequestBody = { displayName: string };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const uid = userId(ctx);
      const input = await body<RequestBody>(request);
      const displayName = requiredString(input.displayName, "displayName", 60);
      const { error } = await ctx.supabaseAdmin.from("profiles").upsert({
        user_id: uid,
        display_name: displayName,
        is_demo: false,
        updated_at: new Date().toISOString(),
      });
      if (error) throw error;
      return ok({ ok: true });
    } catch (error) {
      return failure(error);
    }
  }),
};
