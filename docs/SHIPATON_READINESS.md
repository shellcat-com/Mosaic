# Shipaton Next Gen readiness

Last audited: August 31, 2026. Re-check the [official rules](https://revenuecat-shipaton-2026.devpost.com/rules) immediately before submission.

## Submission route

Mosaic is prepared for **Next Gen only**. Every official team member must remain an active student and use a qualifying academic email on Devpost. Next Gen accepts a working app demonstrated with RevenueCat Test Store, public open-source code, and a public video, so no paid Apple developer account or store release is required.

Do not select another category unless Mosaic receives its first supported-store release during the submission window and can provide the required judge access.

## Implemented locally

- The shipping `MosaicV3` target links RevenueCat Purchases 5.82.0; RevenueCatUI is absent.
- The normal `Mosaic` scheme uses the ignored Test Store public key through `Config/Debug.xcconfig` in Debug. Release validation rejects `test_` keys.
- RevenueCat identity is the lowercase Supabase UUID and is cleared when the Mosaic session ends.
- The current custom Living Kiln paywall loads annual, monthly, and Event Pass cards only from offering `organizer_plus_v1`, selects annual by default, and supports loading, retry, cancellation, pending, restore, success, and server synchronization states.
- VoiceOver labels, Dynamic Type, 44-point targets, Reduce Motion, Reduce Transparency, and non-color selection are represented in the paywall implementation.
- Free and premium creation rules are enforced in SQL. `mosaics.access_source` is immutable, so expiry never damages an existing event.
- `refresh-billing`, `revenuecat-webhook`, and `create-premium-mosaic` keep RevenueCat secrets server-side and make PASS debit resumable and idempotent.
- Swift tests, deterministic paywall showcase fixtures, RevenueCat parser tests, webhook tests, and pgTAP billing/security coverage are included.
- The catalog identifiers are centralized: entitlement `organizer_plus`, products `organizer_monthly`, `organizer_annual`, `mosaic_event_pass_v2`, and virtual currency `PASS`.
- The existing icon is 1024×1024 and the repository contains a 1179×2556 frameless screenshot candidate, an MIT license, captions, and submission copy.
- A clean iPhone 17 Pro Simulator build passes all 51 focused Swift tests across 12 suites, including account-bound private-state cleanup, in-flight request invalidation, newest-detail-response ordering, and Event Pass retry idempotency across unchanged and edited drafts.

## Live catalog read-only audit

The Test Store offering is current and exposes:

| Package | Product |
| --- | --- |
| `$rc_annual` | `organizer_annual` |
| `$rc_monthly` | `organizer_monthly` |
| `event_pass` | `mosaic_event_pass_v2` |

Before any RevenueCat dashboard write, confirm in the authenticated dashboard that monthly and annual grant `organizer_plus`, Event Pass grants exactly one `PASS`, and `organizer_plus_v1` remains current. Dashboard writes require explicit user confirmation.

## External gates still required

- Apply the focused billing migration and deploy the three billing Edge Functions to the intended Supabase project with `REVENUECAT_PROJECT_ID`, `REVENUECAT_SECRET_API_KEY`, and `REVENUECAT_WEBHOOK_SECRET` configured.
- Complete genuine Test Store checks for monthly, annual, Event Pass, restore, relaunch persistence, cancellation, pending payment, and insufficient PASS.
- Re-record a 100–110 second V3 video showing the core Mosaic flow, this custom paywall, genuine Test Store purchase, server-confirmed Plus state, and the unlocked 100-tile choice.
- Replace the legacy submission capture with a freshly reviewed V3 1179×2556 frameless screenshot and add a populated paywall gallery image.
- Push the complete V3 source and tests to public `main`, then verify the README and MIT license while signed out.
- Upload the video publicly to YouTube or Vimeo and replace the placeholder in `docs/SHIPATON_SUBMISSION.md`.
- Sign into Devpost, join the hackathon, create the draft, complete every required field, preview it, and submit. The current browser session is signed out, so this remains an external audit gate.

## Final commands

```sh
xcodegen generate
xcodebuild -project Mosaic.xcodeproj -scheme Mosaic \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
supabase start
supabase db reset
supabase test db
supabase db lint --local --schema public --schema private
deno test --config supabase/functions/refresh-billing/deno.json \
  supabase/functions/_shared/revenuecat_test.ts
deno test --config supabase/functions/revenuecat-webhook/deno.json \
  supabase/functions/revenuecat-webhook/index_test.ts
./scripts/validate_shipaton_submission.sh --final
```
