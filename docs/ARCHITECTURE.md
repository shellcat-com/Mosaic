# Mosaic v3 technical architecture

## Client

`MosaicAppModel` is a small root facade over five feature stores:

- `SessionStore`: Apple session, required profile/display name, sign out, deletion.
- `MosaicLibraryStore`: joined event summaries, invitation previews, create/join.
- `MosaicDetailStore`: event, activities, atomic contributions, notes, reveal outcomes, gallery safety actions.
- `CameraStore`: event-scoped shot ledger, developed review frame, upload retry state, sealed roll.
- `BillingStore`: RevenueCat identity, live offering packages, purchase/restore state, and the last server-authoritative snapshot.

The SwiftUI root uses a stable three-tab `TabView` and `MosaicRoute` navigation values. UI state is `@MainActor @Observable`; Supabase access, disk storage, sensitive-content analysis, and recap rendering cross actor boundaries.

## Data boundary

| Data | Storage | Access invariant |
| --- | --- | --- |
| Profile | `profiles` | Self only; post-reveal names are emitted by the authorized event function. |
| Event | `mosaics`, `mosaic_members` | Members only; invitation preview is a narrow function available before reveal. |
| Activities | `kindness_activities` | Members only. |
| Contributions | `kindness_contributions` | Own row before reveal; all joined-member rows after reveal. Aggregate occupied positions remain visible before reveal. |
| Photos | `event_photos`, private `event-photos` bucket | Own eligible photos before reveal; joined members after reveal; quarantine and block filters always apply. |
| Safety | `event_photo_reports`, `user_blocks` | Reporter/blocker scoped. |
| Artwork package | `private.artwork_reveal_packages` | Released only to a member after fixed reveal. |
| Billing snapshot | `billing_accounts` | User-owned read; service-role reconciliation is the only write path. |
| RevenueCat events | `private.revenuecat_events` | Bearer-authenticated webhook, event ID + payload-hash idempotency. |
| PASS redemption | `private.pass_redemptions` | User/request scoped reservation; RevenueCat debit uses the same idempotency key. |

The v3 migration enables RLS on every exposed table, revokes default table/function access, explicitly grants only required operations, and exposes narrow functions. Atomic contribution placement locks the event row and relies on uniqueness for both `(mosaic, activity, participant)` and `(mosaic, tile_position)`.

## Billing authority

After Supabase authentication, RevenueCat is configured with the lowercase Supabase UUID. The custom SwiftUI paywall reads the current `organizer_plus_v1` offering and never invents prices, trials, renewal language, or savings. Purchase and restore success enter a synchronizing state; `refresh-billing` reads RevenueCat API v2 entitlements, subscriptions, and `PASS`, then overwrites `billing_accounts`. The server snapshot—not CustomerInfo—unlocks creation choices.

`v3_create_mosaic` enforces the free contract and concurrent-event limit. Plus is selected automatically when active. Without Plus, `create-premium-mosaic` reserves one local mirrored PASS, debits one RevenueCat `PASS` with `Idempotency-Key`, and creates the Mosaic in the same resumable request. A trigger makes `mosaics.access_source` immutable, so later subscription expiry changes only eligibility for new events.

## Photo pipeline

`AVCapturePhotoOutput → review/retake → SensitiveContentAnalysis → permanent event film development → protected local JPEG → prepare row → private Storage upload → finalize row`

Only `image/jpeg` up to 12 MiB is accepted. One prepared/eligible row consumes a shot, so concurrent prepares cannot overrun the event limit. A prepared capture may finalize after reveal for offline retry; new captures cannot begin after reveal. The original capture bytes are discarded after the developed JPEG is produced.

## Recap boundary

`PhotoRecapProject` contains only event ID, ordered photo IDs, template, music, and trim offset. `PhotoRecapRenderer` resolves those IDs in order and emits each once. The export is on-device and is never uploaded. The type system offers no artwork, contribution, note, identity, title, caption, or statistics input to the renderer.

## Scheduled reveal

`private.mark_due_mosaics_revealed()` records due reveals every minute through `pg_cron`. Authorization also compares `now()` directly with `reveal_at`, so access boundaries do not depend on scheduler latency. No early organizer reveal exists.
