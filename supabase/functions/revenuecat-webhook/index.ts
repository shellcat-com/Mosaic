import "@supabase/functions-js/edge-runtime.d.ts";
import { createHash } from "node:crypto";
import { withSupabase } from "@supabase/server";

export function parseWebhook(raw: string) {
  const payload = JSON.parse(raw) as { event?: Record<string, unknown> };
  const event = payload.event;
  if (
    !event || typeof event.id !== "string" || typeof event.type !== "string"
  ) throw new Error("Malformed RevenueCat event");
  const appUserID = typeof event.app_user_id === "string"
    ? event.app_user_id
    : "";
  return { eventID: event.id, eventType: event.type, appUserID };
}

export default {
  fetch: withSupabase<any>({ auth: "none" }, async (request, ctx) => {
    const expected = Deno.env.get("REVENUECAT_WEBHOOK_SECRET")?.trim();
    const provided = request.headers.get("authorization")?.replace(
      /^Bearer\s+/i,
      "",
    ).trim();
    if (!expected || provided !== expected) {
      return Response.json({ error: "Unauthorized" }, { status: 401 });
    }
    try {
      const raw = await request.text();
      const event = parseWebhook(raw);
      const payloadHash = createHash("sha256").update(raw).digest("hex");
      const { data, error } = await ctx.supabaseAdmin.rpc(
        "v3_internal_record_revenuecat_event",
        { ...event, payloadHash },
      );
      if (error) throw error;
      return Response.json(data, { status: 200 });
    } catch (error) {
      return Response.json({
        error: error instanceof Error
          ? error.message
          : "Malformed RevenueCat event",
      }, { status: 400 });
    }
  }),
};
