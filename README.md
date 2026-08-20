# Mosaic

Mosaic turns verified acts of kindness into an equal-weight collaborative ceramic artwork. It is a SwiftUI and Supabase project built for the App Development track at Reverie Hacks 2026.

## Quick start

1. Clone this repository.
2. Open `Mosaic.xcodeproj`.
3. Select an iPhone Simulator.
4. Run the `Mosaic` scheme.

No private credentials are required. Without a reachable Supabase project, the app opens its bundled read-only demo so the complete visual journey remains judgeable. For the live two-user flow, start the included local backend first:

```sh
supabase start
```

The debug build automatically connects to `http://127.0.0.1:55321`. Anonymous authentication creates a persistent guest identity; the seeded showcase is read-only, while every installation receives one isolated synthetic organizer sandbox. Sign in with Apple is optional post-hackathon account recovery and preserves the same Supabase UUID.

## What is implemented

- Anonymous guest onboarding with name and identity-privacy choices.
- Native Sign in with Apple linking that preserves the anonymous Supabase UUID and contributions.
- Owner/admin/reviewer workspaces, seven-day single-use collaborator invites, and organization switching.
- RevenueCat Paywall V2 integration, Organizer Plus state, restore, and atomic non-expiring PASS redemption.
- A synthetic, read-only showcase plus a deterministic per-installation organizer sandbox.
- Reflection, photo, video, receipt, and organizer-approval evidence paths.
- Private evidence and memory storage with signed upload/download access.
- Independent memory inclusion, identity display, and export-consent controls.
- Separate organizer decisions for evidence and memories.
- Atomic tile placement, private Realtime invalidations, and synchronized manual or scheduled reveal.
- A membership-scoped event agenda with upcoming, active, reveal, and retained recap states.
- Exact reveal times, revision-aware local reminders, Apple Calendar event editing, and deep links.
- App Group summary caching plus configurable Home Screen and Lock Screen widgets.
- Privacy-safe recap thumbnails and opt-in ActivityKit/APNs delivery infrastructure.
- Cached read-only recovery and retryable local drafts when writes fail.
- RLS, explicit Data API grants, pgTAP policies, Edge Functions, seed data, and a minute-level reveal cron.

Partner confirmation is intentionally labeled as post-hackathon work and is not required by any judged mission. Push and Live Activity delivery are best-effort and require the Apple/Supabase production credentials described in `docs/NOTIFICATIONS.md`; the app, local reminders, Calendar editor, widgets, and cached recaps remain useful without them.

## Local backend

Requirements: Xcode 26+, XcodeGen, Docker, Supabase CLI, `curl`, and `jq`.

```sh
supabase start
supabase db reset
supabase functions serve
```

In a second terminal, run the two-user lifecycle check:

```sh
./supabase/functions/tests/integration.sh
```

Database verification:

```sh
supabase test db
supabase db lint --local
supabase db advisors --local
supabase migration list --local
```

Regenerate the Xcode project after changing `project.yml`:

```sh
xcodegen generate
```

## Hosted demo configuration

The app accepts the hosted project URL and publishable key through build settings. These are client identifiers; never add a secret key, service-role key, database password, or CLI token to the app or repository.

```sh
xcodebuild \
  -project Mosaic.xcodeproj \
  -scheme Mosaic \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  SUPABASE_URL='https://YOUR_PROJECT.supabase.co' \
  SUPABASE_PUBLISHABLE_KEY='sb_publishable_YOUR_KEY'
```

For a contributor-only override, create `Config/Local.xcconfig`; that path is ignored by Git. The hosted judge values should be committed in a demo build configuration only after the dedicated synthetic-data project is created, then rotated or retired after judging.

## Project map

- `Mosaic/` — SwiftUI app, design system, repository, and Supabase adapter.
- `MosaicTests/` — UI-state, transport decoding, consent, and design tests.
- `supabase/migrations/` — schema, RLS, Storage, Realtime, cron, and atomic placement.
- `supabase/functions/` — authenticated state-transition endpoints.
- `supabase/tests/` — pgTAP isolation and lifecycle tests.
- `docs/ARCHITECTURE.md` — trust boundaries and data flow.
- `docs/DEMO_SCRIPT.md` — three-minute Reverie Hacks judging walkthrough.
- `docs/NOTIFICATIONS.md` — Apple capabilities, Edge Function secrets, and safe dispatch scheduling.
- `docs/MONETIZATION_SETUP.md` — RevenueCat, App Store Connect, webhook, Apple auth, and judge-demo setup.
- `SECURITY.md` — security model and reporting guidance.

## License and credits

Source code is available under the [MIT License](LICENSE). Third-party fonts and public-domain artwork are documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
