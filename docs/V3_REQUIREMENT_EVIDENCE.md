# Mosaic v3 requirement evidence

Updated: 2026-08-26

This matrix separates source-complete behavior from work that can only be proven with hosted credentials, a signed physical device, or App Store Connect. “Verified” means the implementation exists in the shipping `MosaicV3` target and has local automated or simulator evidence.

| Product requirement | Status | Evidence |
| --- | --- | --- |
| Three stable tabs and typed navigation | Verified | `MosaicRootView.swift`, `MosaicRoute.swift`, and UI destination tests in `MosaicFlowUITests.swift`. |
| Required Apple account and display name; no anonymous mode | Source verified; signed-device gate | `SignInView.swift`, `SessionStore.swift`, anonymous auth disabled in `supabase/config.toml`; real Apple credential exchange requires signing. |
| Invitation-only Create/Join flow | Verified | Six-step `CreateMosaicView.swift`, `JoinMosaicView.swift`, QR/link output, creation/join UI tests, and a simulator URL-open test that routes an already-running signed-in app reactively. |
| Organizer activities, one completion per account, optional note, undo | Verified | `KindnessViews.swift`, `MosaicDetailStore.swift`, unique database constraint, atomic RPCs, Swift domain tests, and pgTAP. |
| Equal-size capacity-limited ceramic tiles; no points/rankings/proof | Verified | `MosaicBoards.swift`, focused v3 schema/domain, recap/UI negative assertions, and no legacy target sources in `project.yml`. |
| Fixed reveal closes input and completes unfinished artwork | Verified | `MosaicPhase`, scheduled backend reveal, pgTAP, incomplete-board domain test, and 100-tile UI reveal test. |
| Artwork remains unknown before reveal | Verified locally | API emits `SealedArtwork` before reveal; invitation/event pgTAP assertions; active UI tests reject artwork title exposure. |
| Encrypted artwork release | Source verified; hosted execution gate | Private package table/RLS/RPC, service-only `prepare_v3_artwork_packages.mjs`, `ArtworkRevealCache.swift`, AES-GCM/SHA-256 tests, and revealed UI integration. Hosted execution is deliberately pending backup/migration. |
| Photo-only in-app disposable camera | Source verified; device gate | `CameraCaptureController.swift`, `EventCameraView.swift`, `CameraStore.swift`; deterministic developing, retake, keep, and shot-accounting states pass on simulator and physical iPhone, while live camera hardware and permission recovery still require release-environment verification. |
| Permanent event film look and on-device sensitive-content screen | Source verified; device gate | `DisposableCameraFilter.swift`, `SensitivePhotoAnalyzer.swift`, and filter tests; Sensitive Content Analysis needs supported hardware validation. |
| Shot accounting, retakes, active deletion restore, sealed roll | Verified | `ShotLedger.swift`, `CameraStore.swift`, Swift tests, storage/RPC enforcement, and pgTAP. |
| Pre-reveal own photos only; organizer has no exception | Verified | RLS policies and member/organizer pgTAP identities. |
| Post-reveal member gallery, reporting, quarantine, blocking | Verified | `PhotoGalleryView.swift`, account blocked-user UI, RLS/RPCs, and pgTAP. |
| Photos-only personal recap with 1–24 ordered selections | Verified | `PhotoRecapModels.swift`, builder UI, timed template playback, renderer, structural negative tests, and simulator/physical-device interaction tests. |
| Every selected photo exactly once; existing template/music behavior | Verified | Ordering/deduplication tests, distinct template timing/layout/grade code, music trimming and credits. |
| 1080×1920 24-photo local export | Simulator verified; device gate | Real 43.2-second render test under a three-minute ceiling; final thermal/memory and Photos save/share need device validation. |
| Recap excludes artwork, notes, names, labels, captions, statistics | Verified | Restricted `PhotoRecapProject` shape, renderer inputs, unit reflection test, and UI negative assertions. |
| Accessibility and Reduce Motion | Automated simulator verified; device/manual gate | System accessibility audits across six primary surfaces, dedicated XXXL journeys, semantic boards/labels, dense-board full-size contribution rows, 44-point controls, deterministic light/dark contrast tests, reduced-motion 100-tile reveal, portrait product contract, and physical-device rendering of account/event destinations; manual assistive-technology pass remains. |
| Supabase destructive v3 reset, RLS, Storage, deterministic seed | Locally verified; hosted gate | Full local reset, 48 pgTAP assertions, and zero lint errors; hosted backup/reset deliberately not executed. |
| Participants remain free; organizer Plus/Event Pass limits are server-authoritative | Source and simulator verified; live-store gate | RevenueCat Purchases and the native paywall are isolated behind `BillingStore`; server reconciliation and PASS idempotency are covered by Swift/Deno/pgTAP tests. Genuine Test Store purchase, restore, cancellation, pending, and relaunch checks remain external gates. |
| App Store disclosures, policies, attribution, support | Source complete; App Store gate | README, architecture, disclosures, metadata draft, review audit, 6.9-inch screenshots, privacy manifest, terms/support/community pages, and `THIRD_PARTY_NOTICES.md`; export documentation, age rating, live review invitations, distribution upload, and App Store Connect entry remain external. |

## Local verification snapshot

- Swift Testing: 34 tests across 10 suites, all passing, including a real 24-photo Full HD export and light/dark primary, accent, and secondary contrast regressions.
- XCTest UI: 14 flows, all passing together on the simulator; the suite includes a six-surface system accessibility audit, Accessibility XXXL journeys, dense-board access, and a revealed artwork finished-state assertion.
- pgTAP: 48 assertions, all passing.
- Database lint: no errors in `public` or `private`.
- Simulator build-for-testing: passing on iPhone 17 Pro, arm64.
- Release archive: passing for the primary `Mosaic` scheme, arm64, Apple Development signed.
- Physical iPhone: signed build/install/launch passing; all seven original deterministic UI flows passed, and the new tactile placement/camera-review/recap-playback journey passed in 60.426 seconds on 2026-08-26.

## Release-only blockers

1. Authenticate the Supabase CLI, positively identify the linked project as non-production, back it up, purge abandoned legacy Storage objects through the Storage API, and apply v3.
2. Run `scripts/prepare_v3_artwork_packages.mjs` with service-role credentials to encrypt/upload the pending per-Mosaic artwork packages.
3. Complete signed-device Apple authentication, camera, Sensitive Content Analysis, offline retry, protected-file, Photos save/share, and assistive-technology testing.
4. Validate the live RevenueCat catalog and genuine Test Store purchase, restore, cancellation, pending, relaunch, and insufficient-PASS paths against server reconciliation.
5. Repair the Xcode developer-account credential and create/download an App Store distribution profile for `com.biswaskhatiwada.mosaicapp`, then export and finish App Store Connect privacy/metadata/IAP/submission operations.
