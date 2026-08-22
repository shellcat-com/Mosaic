import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { failure, HttpError, ok } from "../_shared/mosaic.ts";

type RevenueCatEvent = {
  id?: string;
  type?: string;
  app_user_id?: string;
  product_id?: string;
  transaction_id?: string;
  event_timestamp_ms?: number;
  expiration_at_ms?: number | null;
  expiration_reason?: string | null;
  period_type?: string;
};

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)].map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

function statusFor(event: RevenueCatEvent): string {
  switch (event.type) {
    case "INITIAL_PURCHASE":
      return event.period_type === "TRIAL" ? "trialing" : "active";
    case "RENEWAL":
    case "UNCANCELLATION":
      return "active";
    case "BILLING_ISSUE":
      return "billing_issue";
    case "CANCELLATION":
      return "cancelled";
    case "EXPIRATION":
      return "expired";
    default:
      return "none";
  }
}

export default {
  fetch: withSupabase<any>({ auth: "none" }, async (request, ctx) => {
    try {
      if (request.method !== "POST") throw new HttpError(405, "POST required");
      const expected = Deno.env.get("REVENUECAT_WEBHOOK_AUTH");
      if (
        !expected ||
        request.headers.get("authorization") !== `Bearer ${expected}`
      ) {
        throw new HttpError(401, "Invalid webhook authorization");
      }
      const raw = await request.text();
      const envelope = JSON.parse(raw);
      const event = envelope?.event as RevenueCatEvent;
      if (!event?.id || !event?.type || !event?.app_user_id) {
        throw new HttpError(400, "Invalid RevenueCat event");
      }
      const occurredAt = new Date(event.event_timestamp_ms ?? Date.now());
      const expiresAt = event.expiration_at_ms
        ? new Date(event.expiration_at_ms).toISOString()
        : null;
      const isPass = event.type === "NON_RENEWING_PURCHASE" &&
        ["mosaic_event_pass", "mosaic_event_pass_v2"].includes(
          event.product_id ?? "",
        );
      const willRenew = !["CANCELLATION", "EXPIRATION"].includes(event.type);
      const { data, error } = await ctx.supabaseAdmin.rpc(
        "internal_process_billing_event",
        {
          target_event_id: event.id,
          target_event_type: event.type,
          target_customer_id: event.app_user_id,
          target_product_id: event.product_id ?? null,
          target_transaction_id: event.transaction_id ?? null,
          target_occurred_at: occurredAt.toISOString(),
          target_payload_sha256: await sha256(raw),
          target_status: isPass ? "none" : statusFor(event),
          target_expires_at: expiresAt,
          target_will_renew: isPass ? false : willRenew,
          pass_delta: isPass ? 1 : 0,
        },
      );
      if (error) throw error;
      return ok({ processed: data === true });
    } catch (error) {
      return failure(error);
    }
  }),
};
