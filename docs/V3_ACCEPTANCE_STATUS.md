# Mosaic v3 acceptance status

Updated: 2026-08-26

## Automated and passing locally

- The focused iOS target builds for the iOS Simulator with Swift 6.
- 34 focused Swift tests across 10 suites cover phase resolution, all supported board sizes, incomplete-board reveal, draft validation, typed routing, placement/reveal playback, shot accounting, durable pending-upload manifests, all three film looks, recap ordering and deduplication, the 24-photo limit, distinct template timing, exclusion of non-photo recap inputs, encrypted-artwork integrity/decryption, billing rules/state, and light/dark primary, accent, and secondary foreground contrast.
- A full local Supabase reset applies every historical migration followed by the destructive v3 reset and deterministic seed.
- Database lint reports no errors in `public` or `private`.
- 48 pgTAP checks cover pre/post-reveal RLS, organizer isolation, nonmember denial, uniqueness, board capacity, note editing and withdrawal, JPEG validation, idempotent offline-photo reservation, shot exhaustion and restoration, report quarantine, block filtering, creator deletion, joining/photography closure, scheduled reveal, sealed artwork metadata, reveal-key locking, and service-only package registration.
- The repository-wide `supabase test db` command now runs only the focused v3 operations and security suites; obsolete tests for the destructively removed legacy schema were removed.
- Real SwiftUI simulator captures cover the home, create, active board, completed artwork, separate gallery, visual recap style picker, and disposable camera. Accessibility XXXL was exercised on the home flow, with adaptive vertical controls and cards.
- Fourteen XCTest UI flows pass together against deterministic in-app fixtures: account/deletion surfaces, active/revealed/photo destination separation and finished reveal copy, the complete six-step creation wizard, join/activity/camera/photo-only recap contracts, camera-denial recovery, animated and reduced-motion 100-tile reveals, confirmed account deletion, an invitation URL opened into an already-running signed-in app, tactile placement/camera/recap editing, current billing states, dense-board contribution access, and Accessibility XXXL adaptations for active events, recap, and disposable camera.
- XCTest's system accessibility audit passes across Home, Create, active and revealed Mosaics, Camera, and Recap. Dedicated XXXL UI journeys cover Dynamic Type, and deterministic light/dark palette tests cover custom-font contrast.
- The final material-identity pass was captured from the real target under `design/ui-review-v3-final/`. Against that exact source, destination separation, the photo-only camera/recap contract, and the animated 100-tile reveal passed on a clean iPhone 17 Pro Max simulator (3 tests, zero failures).
- The generated project signs both XCTest bundles for physical devices, and the vertical camera/reel product explicitly supports portrait orientation. A signed Debug build installed and launched on an iPhone running iOS 26.5. All seven original deterministic UI flows pass on that device, and the new tactile placement/camera-review/recap-playback journey passed there in 60.426 seconds on 2026-08-26. The complete eight-flow suite passed together on the simulator with zero failures in 281.633 seconds.
- A real 24-photo recap render passes at 1080×1920, contains the expected 43.2 seconds of video, and runs inside a three-minute test ceiling without retaining all decoded source images. The latest unified run completed it in 109.097 seconds; observed simulator render times range from about 34 seconds on a clean run to 136 seconds under heavy host load.
- Artwork metadata now remains sealed in invitations, lists, and event payloads before reveal. The v3 client downloads the private ciphertext after reveal, verifies SHA-256, decrypts AES-GCM using event-bound authenticated data, and stores the JPEG with iOS file protection.
- The primary `Mosaic` scheme produces a signed arm64 Release archive for bundle `com.biswaskhatiwada.mosaicapp`; `/tmp/Mosaic-v3-exact-final.xcarchive` was rebuilt from byte-for-byte synchronized post-audit source and its structure, strict code signature, portrait contract, privacy manifests, AES-GCM export declaration, and lack of legacy release strings were validated on 2026-08-25.
- Seven opaque 1320×2868 JPEG screenshots captured from the real SwiftUI target cover Home, Create, active Kindness, Camera, revealed Artwork, Photos, and the photo-only Recap builder under `design/app-store-screenshots/6.9-inch/`.

## Requires CI, device, or release-environment validation

- The hosted non-production v3 migration has not been applied. This Mac currently has no Supabase CLI access token, and the intended hosted project has not been confirmed as non-production. Back up the hosted project and purge legacy Storage buckets through the Storage API before deployment.
- The private reveal-package schema, release-time access function, Storage policy, service-role packaging script, and client decryption are present. The packaging script still must be executed after the hosted migration; the reviewed bundled artwork remains the offline fallback.
- Real Sign in with Apple, physical camera permission denial and Settings recovery, live capture, on-device sensitive-content analysis, protected-file behavior, offline upload retry, and saving to Photos require signed release-environment testing. Their deterministic UI states pass on the physical device.
- Deterministic simulator UI automation covers those product surfaces, including a real custom-scheme URL-open event and the complete deletion transition. Real Apple authentication, physical camera capture, Photos export, and hosted destructive account execution still require signed release-environment runs.
- Hands-on VoiceOver traversal, Voice Control, Switch Control, real Settings-based camera permission recovery, and thermal/memory profiling still require physical-device acceptance. System accessibility audits, Maximum Dynamic Type, animated and reduced-motion 100-tile reveals, and a 24-photo 1080×1920 export have passed automated validation.
- The source-level accessibility audit and physical-device acceptance procedure are recorded in `skills/swiftui-accessibility-auditor/checklist.md`.
- Distribution export/upload and App Store Connect metadata/privacy answers remain release operations, not local source changes. The validated local archive uses Apple Development signing and is not an App Store submission artifact.
- A local App Store Connect export was attempted without upload and failed because Xcode has no valid App Store distribution profile for `com.biswaskhatiwada.mosaicapp` and its stored developer-account credential is incomplete. This is now a concrete signing/account gate rather than an untested assumption.
- The section-by-section App Store result is in `docs/APP_STORE_REVIEW_AUDIT.md`. Export-compliance documentation, the current age-rating questionnaire, live reviewer invitations, metadata entry, privacy-form reconciliation, and processed-build validation remain authenticated release gates.

The v3 migration is intentionally destructive and must not be pushed to a hosted project without the backup and Storage cleanup gate above.

The requirement-by-requirement evidence map is in `docs/V3_REQUIREMENT_EVIDENCE.md`.
