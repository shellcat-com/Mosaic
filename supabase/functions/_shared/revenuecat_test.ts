import {
  billingState,
  isoDateFromMilliseconds,
  passBalance,
} from "./revenuecat.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("billing state matches opaque entitlement IDs and PASS balances", () => {
  const state = billingState(
    "entl_mosaic_plus",
    [{ entitlement_id: "entl_mosaic_plus", expires_at: 1_800_000_000_000 }],
    [{
      product_id: "prod_internal",
      gives_access: true,
      auto_renewal_status: "will_renew",
      status: "trialing",
      entitlements: {
        items: [{
          id: "entl_mosaic_plus",
          products: {
            items: [{
              product: {
                id: "prod_internal",
                store_identifier: "organizer_annual",
              },
            }],
          },
        }],
      },
    }],
    [{ currency_code: "PASS", balance: 3.9 }],
  );
  assert(state.plusActive, "expected Plus to be active");
  assert(state.subscriptionStatus === "trialing", "expected trialing state");
  assert(state.productId === "organizer_annual", "expected store product ID");
  assert(state.willRenew, "expected renewable subscription");
  assert(state.passBalance === 3, "expected an integer PASS balance");
  assert(state.expiresAt === "2027-01-15T08:00:00.000Z", "expected ISO date");
});

Deno.test("inactive entitlement clears subscription access but retains PASS", () => {
  const state = billingState(
    "entl_mosaic_plus",
    [],
    [{
      status: "expired",
      entitlements: { items: [{ id: "entl_mosaic_plus" }] },
    }],
    [{ currency_code: "PASS", balance: 1 }],
  );
  assert(!state.plusActive, "expected Plus to be inactive");
  assert(
    state.subscriptionStatus === "none",
    "expected free subscription state",
  );
  assert(state.productId == null, "expected product to be cleared");
  assert(state.expiresAt == null, "expected expiry to be cleared");
  assert(state.passBalance === 1, "expected PASS to remain available");
});

Deno.test("date and balance parsing reject malformed values", () => {
  assert(
    isoDateFromMilliseconds("not-a-date") == null,
    "invalid date must be null",
  );
  assert(
    passBalance([{ currency_code: "PASS", balance: -4 }]) === 0,
    "balance must not be negative",
  );
  assert(
    passBalance([{ currency_code: "COIN", balance: 4 }]) === 0,
    "missing PASS must be zero",
  );
});

Deno.test("RevenueCat grace-period status maps to the database enum", () => {
  const state = billingState(
    "entl_mosaic_plus",
    [{ entitlement_id: "entl_mosaic_plus" }],
    [{
      status: "in_grace_period",
      gives_access: true,
      entitlements: { items: [{ id: "entl_mosaic_plus" }] },
    }],
    [],
  );
  assert(state.subscriptionStatus === "grace_period", "expected grace period");
});

Deno.test("billing retry and disabled renewal retain access with accurate state", () => {
  const entitlement = [{ entitlement_id: "entl_mosaic_plus" }];
  const billingRetry = billingState(
    "entl_mosaic_plus",
    entitlement,
    [{
      status: "in_billing_retry",
      entitlements: { items: [{ id: "entl_mosaic_plus" }] },
    }],
    [],
  );
  assert(billingRetry.plusActive, "billing retry should retain active access");
  assert(
    billingRetry.subscriptionStatus === "billing_issue",
    "expected billing issue",
  );

  const cancelled = billingState(
    "entl_mosaic_plus",
    entitlement,
    [{
      status: "active",
      auto_renewal_status: "will_not_renew",
      entitlements: { items: [{ id: "entl_mosaic_plus" }] },
    }],
    [],
  );
  assert(
    cancelled.plusActive,
    "cancelled renewal should retain access to expiry",
  );
  assert(
    cancelled.subscriptionStatus === "cancelled",
    "expected cancelled state",
  );
  assert(!cancelled.willRenew, "cancelled subscription must not renew");
});
