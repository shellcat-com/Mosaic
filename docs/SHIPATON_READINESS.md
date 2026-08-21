# Shipaton submission readiness

Last audited: August 21, 2026. Re-check the official Devpost rules immediately
before submission because the organizer may update dates or requirements.

Primary references: [official rules](https://revenuecat-shipaton-2026.devpost.com/rules)
and the [organizer's Next Gen category clarification](https://revenuecat-shipaton-2026.devpost.com/forum_topics/44575-eligibility-for-next-gen-award-and-other-categories).

## Submission route

Mosaic's currently viable route is a **Next Gen candidate** submission, not a
multi-category submission. The package is not submission-complete until the
blocking items below are resolved.

Next Gen requires every submitting team member to be an active student in a
high school, college, university, bootcamp, or other academic program and to use
a qualifying student or academic email on Devpost. It accepts a public,
open-source repository plus the demo video instead of a store listing.

To enter RevenueCat Peace Prize, RevenueCat Design Award, or any other
non-Next-Gen category as well, version 1.0 must be published for the first time
on a supported store during the Shipaton submission period. A free trial or
judge promo code is also required. Do not select those categories until the
store listing is live.

## Verified locally

- The iOS Shipaton scheme resolves pinned RevenueCat and Supabase packages.
- The full arm64 Simulator test run passes: 65 tests across XCTest and Swift
  Testing, including onboarding, permissions, deep links, lifecycle, design,
  accessibility, and playable recap exports.
- The built Shipaton app installs and launches on iPhone 17 Pro Simulator. Its
  normal startup, custom URL wake-up, onboarding, home, and reveal presentation
  all render without a crash.
- The app icon is exactly 1024x1024.
- The raw submission screenshot is exactly 1179x2556 and has no device frame.
- All five App Store marketing images validate at 1320x2868 opaque RGB.
- The privacy and terms pages respond successfully over HTTPS.
- The hosted Supabase Auth service is reachable using the committed publishable
  client key.
- The local Supabase pgTAP suite passes all 93 tests, and the two-user Edge
  Function integration flow passes against a freshly reset local database.
- The five Shipaton billing/notification Edge Functions missing from the hosted
  project have been deployed and are active.
- RevenueCat response-contract tests pass under Deno.
- Plists and privacy manifests parse successfully.
- The local checkout contains an MIT license, source, assets, backend migrations,
  shared Xcode schemes, tests, and judge instructions.

## Blocking before final submission

- Confirm active-student eligibility and a qualifying academic email for every
  person listed on the Next Gen team.
- Add the RevenueCat Test Store public SDK key to the Shipaton build and run a
  genuine purchase, cancellation, restore, relaunch, entitlement-sync, and PASS
  redemption walkthrough. The key is not currently present in this checkout.
- Record and export `submission/Mosaic-Shipaton-Demo.mp4`. It is currently
  missing. Keep it below two minutes and show the real app on its target device.
- Upload the final video publicly to YouTube or Vimeo, verify it while signed
  out, and replace the placeholder in `docs/SHIPATON_SUBMISSION.md`.
- Push the complete current Shipaton work to the public repository's default
  branch. The public `main` branch does not yet contain this checkout's full
  Shipaton submission state.
- Join the hackathon on Devpost, complete the participant form, and fill every
  required Devpost field before September 30, 2026 at 11:45 PM PDT.

## Required only for Peace Prize or Design Award

- Publish the app's first public store version during the submission window.
- Add the live supported-store URL to the Devpost submission.
- Provide a free trial or a promo code that unlocks all premium features for
  judges.
- Keep the social-good description for Peace Prize and the unique visual design
  and animation description for Design Award in the submission copy.

## Final command

Run this only after the genuine video has been exported and its public URL has
been added:

```sh
./scripts/validate_shipaton_submission.sh --final
```
