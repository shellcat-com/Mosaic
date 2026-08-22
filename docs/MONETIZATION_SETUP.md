# Authentication and monetization setup

The repository contains the client, schema, RLS, Edge Functions, and tests. The following dashboard work uses credentials that must never be committed.

## Supabase

1. Enable anonymous sign-ins and manual identity linking.
2. For native Sign in with Apple, configure the Supabase Apple provider with the iOS App ID/bundle ID `com.biswaskhatiwada.mosaicapp`. The native `signInWithIdToken` flow does not require a web Services ID or rotating OAuth secret unless a web OAuth flow is added later.
3. Deploy migrations and all Edge Functions.
4. Set `REVENUECAT_SECRET_API_KEY`, `REVENUECAT_PROJECT_ID`, `REVENUECAT_ORGANIZER_PLUS_ENTITLEMENT_ID`, and a long random `REVENUECAT_WEBHOOK_AUTH` Edge Function secret. The entitlement value is RevenueCat's opaque `entl…` resource ID, not the `organizer_plus` lookup key.
5. Configure the RevenueCat webhook URL as `/functions/v1/revenuecat-webhook` with `Authorization: Bearer <REVENUECAT_WEBHOOK_AUTH>`.

The webhook stores only event identifiers, product/transaction identifiers, timestamps, and a payload hash. Raw receipts and full webhook payloads are not persisted or logged.

## RevenueCat and App Store Connect

Create these exact identifiers:

| Kind | Identifier | Store configuration |
| --- | --- | --- |
| Entitlement | `organizer_plus` | Attach monthly and annual products |
| Monthly subscription | `organizer_monthly` | $9.99/month |
| Annual subscription | `organizer_annual` | $79.99/year, 7-day introductory trial |
| Consumable | `mosaic_event_pass_v2` | $14.99, grants one `PASS` |
| Offering | `organizer_plus_v1` | Include all three packages |
| Virtual currency | `PASS` | Purchased balance never expires |

Create a Paywall V2 titled **Fire bigger mosaics**. Make annual visually recommended and include renewal/trial terms, a feature comparison, Restore Purchases, Privacy, Terms, and a close control. The app renders this remote paywall through `RevenueCatUI` and provides a separate custom billing screen.

For Shipaton, configure Test Store products using the identifiers above. Attach the monthly and annual products to `organizer_plus`, grant one unit of virtual currency `PASS` from `mosaic_event_pass_v2`, make `organizer_plus_v1` current, and publish the Paywall V2. The legacy `mosaic_event_pass` product is retained only so existing Test Store transactions continue to synchronize.

Create a least-privilege RevenueCat secret API key with customer read, subscription read, and purchase/virtual-currency read-write permissions. `refresh-billing` reads the customer's active entitlements, subscriptions, and virtual-currency balance from their dedicated RevenueCat API v2 endpoints. The secret key is used only by hosted Edge Functions.

Set `REVENUECAT_TEST_STORE_PUBLIC_KEY` in `Config/Local.xcconfig` for the Shipaton scheme and `REVENUECAT_APP_STORE_PUBLIC_KEY` for a future Release build. The Test Store SDK key is public client configuration; never place the secret API key in an xcconfig. Release builds reject keys beginning with `test_`.

The shared `Mosaic Shipaton` scheme uses the Debug configuration for Run, Test,
Profile, and Analyze so RevenueCat's Test Store support is compiled in. Archive
uses Release and therefore requires a real platform public SDK key; never archive
or distribute the Test Store build.

## Validation sequence

1. Run `supabase db reset`, `supabase test db`, `supabase db lint --local`, and `supabase db advisors --local`.
2. Use RevenueCat Test Store in Simulator for purchase/cancel/pending/restore UI states.
3. Use hosted staging on a physical device for Sign in with Apple and anonymous identity linking.
4. In the Shipaton scheme, sign in with Apple, create a workspace, complete a Test Store subscription, relaunch, restore purchases, and verify Organizer Plus remains active.
5. Purchase `mosaic_event_pass_v2`, verify a PASS balance of one, redeem it on one challenge, and prove a retry does not debit twice.
6. Keep the billing-disabled Reverie scheme available only as an archived reproduction path.
7. Confirm account deletion blocks sole owners and warns that deletion does not cancel an Apple subscription.

## Production release boundary

The Shipaton Next Gen submission is judged through its public source, video, and Test Store purchase. The `Shipaton` configuration enables billing but leaves remote push disabled. A purchase requires a recoverable Sign in with Apple organizer account and selected workspace; participant demo access remains guest-first.

Before a paid public App Store release, complete sandbox purchase and restore testing, add production RevenueCat and notification credentials, verify account deletion, confirm that production builds use only the App Store RevenueCat public key, and re-audit the published [Privacy Policy](https://shellcat-com.github.io/Mosaic/privacy/) and [Terms](https://shellcat-com.github.io/Mosaic/terms/) against the final production data practices.
