import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import {
  body,
  failure,
  HttpError,
  ok,
  requiredUUID,
  requirePermanentAccount,
} from "../_shared/mosaic.ts";
import {
  revenueCatConfiguration,
  revenueCatRequest,
} from "../_shared/revenuecat.ts";

type Input = { requestID?: unknown; payload?: unknown };

export default {
  fetch: withSupabase<any>({ auth: "user" }, async (request, ctx) => {
    let requestID = "";
    let userID = "";
    try {
      userID = requirePermanentAccount(ctx).toLowerCase();
      const input = await body<Input>(request);
      requestID = requiredUUID(input.requestID, "requestID");
      if (
        !input.payload || typeof input.payload !== "object" ||
        Array.isArray(input.payload)
      ) throw new HttpError(400, "payload is required");
      const { data: reservation, error: beginError } = await ctx.supabaseAdmin
        .rpc("v3_internal_begin_pass_redemption", {
          requestID,
          userID,
          payload: input.payload,
        });
      if (beginError) throw beginError;
      if (reservation.state === "completed") {
        return ok({ mosaicID: reservation.mosaicID });
      }
      if (!reservation.shouldDebit) {
        throw new HttpError(409, "PASS reservation is not resumable");
      }

      const { projectID, secretKey } = revenueCatConfiguration();
      await revenueCatRequest(
        projectID,
        secretKey,
        `/customers/${
          encodeURIComponent(userID)
        }/virtual_currencies/transactions`,
        {
          method: "POST",
          headers: { "Idempotency-Key": reservation.idempotencyKey },
          body: JSON.stringify({
            adjustments: { PASS: -1 },
            reference: requestID,
          }),
        },
      );
      const { data: mosaicID, error: completeError } = await ctx.supabaseAdmin
        .rpc("v3_internal_complete_pass_redemption", { requestID, userID });
      if (completeError) throw completeError;
      return ok({ mosaicID });
    } catch (error) {
      // A known 4xx debit failure is safe to release locally. Ambiguous network/5xx
      // outcomes remain reserved so retrying with the same idempotency key is safe.
      if (
        requestID && userID && error instanceof Error &&
        /RevenueCat 4(?!29)\d:/.test(error.message)
      ) {
        await ctx.supabaseAdmin.rpc("v3_internal_fail_pass_redemption", {
          requestID,
          userID,
          reason: error.message,
        });
      }
      return failure(error);
    }
  }),
};
