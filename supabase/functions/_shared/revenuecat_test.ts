import { assertEquals } from "jsr:@std/assert@1";
import { parseBillingSnapshot } from "./revenuecat.ts";

Deno.test("parses active Plus and PASS balance", () => {
  const result = parseBillingSnapshot(
    { items: [{ entitlement_id: "entl_plus", expires_at: 1_893_456_000_000 }] },
    {
      items: [{
        product_id: "prod_annual",
        gives_access: true,
        status: "active",
        current_period_ends_at: 1_893_456_000_000,
        auto_renewal_status: "will_renew",
        entitlements: {
          items: [{
            id: "entl_plus",
            lookup_key: "organizer_plus",
            products: {
              items: [{
                id: "prod_annual",
                store_identifier: "organizer_annual",
              }],
            },
          }],
        },
      }],
    },
    { items: [{ currency_code: "PASS", balance: 2 }] },
    new Date("2029-01-01T00:00:00Z"),
  );
  assertEquals(result.plusActive, true);
  assertEquals(result.productID, "organizer_annual");
  assertEquals(result.passBalance, 2);
  assertEquals(result.willRenew, true);
});

Deno.test("expired entitlement never grants Plus", () => {
  const result = parseBillingSnapshot(
    { items: [{ entitlement_id: "entl_plus", expires_at: 1_577_836_800_000 }] },
    {
      items: [{
        product_id: "prod_monthly",
        gives_access: false,
        status: "expired",
        entitlements: {
          items: [{
            id: "entl_plus",
            lookup_key: "organizer_plus",
            products: {
              items: [{
                id: "prod_monthly",
                store_identifier: "organizer_monthly",
              }],
            },
          }],
        },
      }],
    },
    { items: [] },
    new Date("2029-01-01T00:00:00Z"),
  );
  assertEquals(result.plusActive, false);
  assertEquals(result.subscriptionState, "expired");
  assertEquals(result.passBalance, 0);
});
