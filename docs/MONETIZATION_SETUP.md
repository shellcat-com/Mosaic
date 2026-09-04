# RevenueCat and Supabase billing setup

The repository contains the V3 client, custom paywall, migration, Edge Functions, and deterministic tests. Dashboard credentials and webhook secrets must never be committed.

## Client configuration

1. Copy `Config/Local.xcconfig.example` to the ignored `Config/Local.xcconfig`.
2. Set `REVENUECAT_TEST_STORE_PUBLIC_KEY` to the RevenueCat Test Store public SDK key.
3. Generate the project with `xcodegen generate` and run the normal `Mosaic` scheme.

RevenueCat Purchases is configured only after Supabase authentication, using the lowercase Supabase UUID as `appUserID`. Release builds reject keys beginning with `test_`. Do not put any `sk_` key, V2 secret key, webhook secret, Supabase service-role key, or database password in an xcconfig.

## Exact catalog contract

| Kind | Identifier | Required relationship |
| --- | --- | --- |
| Offering | `organizer_plus_v1` | Current; annual, monthly, and Event Pass packages attached |
| Entitlement | `organizer_plus` | Granted by monthly and annual |
| Monthly | `organizer_monthly` | Package `$rc_monthly` |
| Annual | `organizer_annual` | Package `$rc_annual` |
| Event Pass | `mosaic_event_pass_v2` | Package `event_pass`; grants exactly one `PASS` |
| Virtual currency | `PASS` | Balance is read and spent by the server |

Do not create or publish a RevenueCat Paywall. Mosaic intentionally excludes RevenueCatUI and renders the custom native “Make room for more people” paywall. Prices, periods, introductory offers, and comparable-currency savings are derived from the live offering.

Perform the authenticated dashboard check read-only first. Confirm the relationships above and that the offering remains current. Obtain explicit user confirmation before any dashboard write.

## Supabase deployment

Apply migrations in order, including `20260824235234_mosaic_v3_core_rebuild.sql` and `20260826061805_v3_revenuecat_billing.sql`, then deploy:

- `refresh-billing`
- `create-premium-mosaic`
- `revenuecat-webhook`
- `delete-account`

Set these hosted Edge Function secrets:

- `REVENUECAT_PROJECT_ID`
- `REVENUECAT_SECRET_API_KEY` — a least-privilege V2 secret with customer, subscription, entitlement, and virtual-currency permissions required by the three endpoints
- `REVENUECAT_WEBHOOK_SECRET` — a long random bearer token

Configure RevenueCat’s webhook URL as `/functions/v1/revenuecat-webhook` with `Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>`. The function stores the event ID, type, app user ID, and payload hash; replay of the same ID/hash is accepted, while the same ID with different content is rejected.

## Authority contract

- `refresh-billing` joins RevenueCat’s internal entitlement/product IDs to the `organizer_plus` lookup key and store product identifier, reads `PASS`, and overwrites the local snapshot.
- CustomerInfo is optimistic UI progress only. Premium creation unlocks after the Edge Function confirms the server snapshot.
- `v3_create_mosaic` enforces free and Plus rules in SQL.
- `create-premium-mosaic` reserves one mirrored PASS, sends one RevenueCat virtual-currency transaction with `Idempotency-Key`, and resumes the same request without double debit.
- If Plus is active when a PASS request reaches the server, Plus is used and the PASS stays untouched.
- `mosaics.access_source` is immutable. Expiry affects only future creation.

## Test Store acceptance

Complete and record monthly, annual, Event Pass, restore, relaunch persistence, cancellation, pending payment, insufficient PASS, and retry-after-ambiguous-response scenarios. For each successful purchase, show both the RevenueCat confirmation and the later server-confirmed state. Verify 100 tiles, 36 shots, and all film looks become visible only after reconciliation.

Next Gen does not require a paid Apple developer account or store release. Before a future public App Store release, supply only the production public SDK key to Release, complete StoreKit sandbox review, and re-audit Privacy and Terms against the final production behavior.
