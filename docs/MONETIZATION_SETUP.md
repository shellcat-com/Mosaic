# Authentication and monetization setup

The repository contains the client, schema, RLS, Edge Functions, and tests. The following dashboard work uses credentials that must never be committed.

## Supabase

1. Enable anonymous sign-ins and manual identity linking.
2. Configure Apple as an auth provider with the iOS bundle ID `com.mosaic.kindness` and the Apple secret generated for the hosted project.
3. Deploy migrations and all Edge Functions.
4. Set `REVENUECAT_SECRET_API_KEY`, `REVENUECAT_PROJECT_ID`, and a long random `REVENUECAT_WEBHOOK_AUTH` Edge Function secret.
5. Configure the RevenueCat webhook URL as `/functions/v1/revenuecat-webhook` with `Authorization: Bearer <REVENUECAT_WEBHOOK_AUTH>`.

The webhook stores only event identifiers, product/transaction identifiers, timestamps, and a payload hash. Raw receipts and full webhook payloads are not persisted or logged.

## RevenueCat and App Store Connect

Create these exact identifiers:

| Kind | Identifier | Store configuration |
| --- | --- | --- |
| Entitlement | `organizer_plus` | Attach monthly and annual products |
| Monthly subscription | `organizer_monthly` | $9.99/month |
| Annual subscription | `organizer_annual` | $79.99/year, 7-day introductory trial |
| Consumable | `mosaic_event_pass` | $14.99, grants one `PASS` |
| Offering | `organizer_plus_v1` | Include all three packages |
| Virtual currency | `PASS` | Purchased balance never expires |

Create a Paywall V2 titled **Fire bigger mosaics**. Make annual visually recommended and include renewal/trial terms, a feature comparison, Restore Purchases, Privacy, Terms, and a close control. The app renders this remote paywall through `RevenueCatUI` and provides a separate custom billing screen.

Set `REVENUECAT_TEST_STORE_PUBLIC_KEY` for Debug and `REVENUECAT_APP_STORE_PUBLIC_KEY` for Release in an uncommitted xcconfig or CI secret. Release builds reject keys beginning with `test_`.

## Validation sequence

1. Run `supabase db reset`, `supabase test db`, `supabase db lint --local`, and `supabase db advisors --local`.
2. Use RevenueCat Test Store in Simulator for purchase/cancel/pending/restore UI states.
3. Use hosted staging on a physical device for Sign in with Apple and anonymous identity linking.
4. After the Reverie Hacks repository, video, documentation, and core acceptance tests are complete, test App Store Sandbox and optionally TestFlight, including restore on a second device and exactly-once PASS spend.
5. Confirm account deletion blocks sole owners and warns that deletion does not cancel an Apple subscription.

## Post-hackathon release

RevenueCat products, production Apple authentication, App Store review, and TestFlight are not required for the Reverie Hacks submission. Before a public App Store release, complete sandbox purchase and restore testing, provide review notes and working privacy/terms URLs, verify account deletion, and confirm that production builds use only the App Store RevenueCat public key.
