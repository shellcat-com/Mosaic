import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  assertOrganizationRole,
  body,
  failure,
  HttpError,
  ok,
  requiredUUID,
  userId,
} from "../_shared/mosaic.ts";

type RequestBody = { organizationId?: string; challengeId?: string };

async function adjustPass(
  customerId: string,
  delta: number,
  idempotencyKey: string,
): Promise<string> {
  const apiKey = Deno.env.get("REVENUECAT_SECRET_API_KEY");
  const projectId = Deno.env.get("REVENUECAT_PROJECT_ID");
  if (!apiKey || !projectId) {
    throw new HttpError(503, "RevenueCat server configuration is incomplete");
  }
  const response = await fetch(
    `https://api.revenuecat.com/v2/projects/${
      encodeURIComponent(projectId)
    }/customers/${
      encodeURIComponent(customerId)
    }/virtual_currencies/transactions`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "Idempotency-Key": idempotencyKey,
      },
      body: JSON.stringify({ adjustments: { PASS: delta } }),
    },
  );
  if (!response.ok) {
    throw new HttpError(
      409,
      delta < 0 ? "No Mosaic Pass is available" : "PASS compensation failed",
    );
  }
  const payload = await response.json();
  return String(payload?.id ?? payload?.transaction_id ?? idempotencyKey);
}

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    try {
      const input = await body<RequestBody>(request);
      const organizationId = requiredUUID(
        input.organizationId,
        "organizationId",
      );
      const challengeId = requiredUUID(input.challengeId, "challengeId");
      await assertOrganizationRole(ctx, organizationId, ["owner"]);
      const { data: reservation, error: reservationError } = await ctx
        .supabaseAdmin.rpc(
          "internal_begin_event_pass_redemption",
          {
            target_organization_id: organizationId,
            target_challenge_id: challengeId,
            target_owner_id: userId(ctx),
          },
        );
      if (reservationError) throw reservationError;
      if (reservation?.already_completed) {
        return ok({ grant: reservation.grant ?? null, alreadyRedeemed: true });
      }
      const { data: account, error: accountError } = await ctx.supabaseAdmin
        .from("billing_accounts")
        .select("revenuecat_customer_id").eq("organization_id", organizationId)
        .single();
      if (accountError) throw accountError;
      const transactionId = await adjustPass(
        account.revenuecat_customer_id,
        -1,
        `redeem-${challengeId}`,
      );
      const { data, error } = await ctx.supabaseAdmin.rpc(
        "internal_complete_event_pass_redemption",
        {
          target_challenge_id: challengeId,
          target_transaction_id: transactionId,
        },
      );
      if (error) {
        // The reservation remains pending. Retrying repeats the RevenueCat
        // request with the same challenge-scoped idempotency key, then safely
        // completes the database grant without a second currency debit.
        throw new HttpError(
          503,
          "PASS redemption is pending reconciliation; retry safely",
        );
      }
      return ok({
        grant: data?.grant ?? null,
        alreadyRedeemed: data?.already_completed ?? false,
      });
    } catch (error) {
      return failure(error);
    }
  }),
};
