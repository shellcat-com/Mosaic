# Mosaic V3 iOS Code Audit

**Audit date:** August 31, 2026  
**Audited target:** Shipping `MosaicV3` target defined by `project.yml`  
**Excluded:** The legacy `Mosaic/` app except shared files explicitly included by `project.yml`  
**Method:** Direct static review, targeted repository searches, release/submission validators, screenshot inspection, and clean iPhone 15 Pro Simulator runs with 46 passing Swift tests and 15 passing UI journeys.

## 1. Executive Summary

Mosaic V3 has a sound structure: domain models, infrastructure adapters, observable stores, and SwiftUI features are separated cleanly. The product demonstrates unusual care around accessibility, equal-weight contributions, server-authoritative state, safety, photo-only recaps, and RevenueCat-backed host monetization.

No Critical issue was confirmed. The audit originally found three High issues. Account-scoped sign-out state and Event Pass retry idempotency are now fixed and regression-tested; eager full-resolution gallery hydration remains the unresolved High issue. Camera session work on the main actor and recap render resource management remain important performance issues.

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 1 unresolved / 2 remediated |
| Medium | 12 |
| Low | 8 |

The source/configuration release validator passes. A clean current-source build, all 46 Swift tests, and all 15 UI journeys pass. Current 1179×2556 V3 screenshot and paywall captures pass the non-final Shipaton validator. The final validator still fails because the placeholder video is 97 seconds instead of the preferred 100–110 seconds; the public video URL and user-owned eligibility/publishing steps also remain incomplete.

## 2. Scope and Architecture

### 2.1 Included components

- `MosaicV3/App`, `Domain`, `Infrastructure`, `Stores`, and `Features`
- Shared theme and disposable-camera filter files selected by `project.yml`
- `MosaicV3Tests` and `MosaicV3UITests` structure/evidence
- Supabase migrations, functions, catalog, and database-test contracts relevant to the client
- App configuration, privacy manifest, entitlements, StoreKit configuration, RevenueCat integration, release scripts, and submission documentation

### 2.2 Architecture summary

```text
SwiftUI features
      ↓
@MainActor observable stores
      ↓
MosaicAPI / billing / session abstractions
      ↓
Supabase + RevenueCat + local protected caches
```

Navigation is a three-tab `TabView` with typed routes. The app has explicit restoring, signed-out, display-name, ready, and unavailable states. Supabase remains authoritative for contributions, placement, reveal, moderation, storage, and premium event creation.

### 2.3 Verification constraints

- `./scripts/validate_app_store_release.sh`: **PASS**
- `./scripts/validate_shipaton_submission.sh`: **PASS** with current screenshot, icon, paywall, captions, RevenueCat contract, and placeholder video structure.
- `./scripts/validate_shipaton_submission.sh --final`: **FAIL**, first because the placeholder video is 97 seconds rather than 100–110 seconds; the new public video URL is also still missing.
- Clean current-source iPhone 15 Pro Simulator build: **PASS**; 46 Swift tests across 12 suites and 15 UI journeys: **PASS**.
- The working tree contains extensive pre-existing user changes. Remediation was limited to targeted shipping-V3 files and tests.

## 3. Swift Concurrency

### 3.1 [Remediated High] Account-scoped observable state was not cleared on identity change

**Evidence:** `MosaicV3/Stores/MosaicAppModel.swift:67-79`, `MosaicV3/Stores/MosaicLibraryStore.swift:7-26`, `MosaicV3/Stores/MosaicDetailStore.swift:8-13`  
**Confidence:** High

`signOut()` and `deleteAccount()` reset routes, camera selection, billing, and session, but do not clear `library.mosaics`, `detail.event`, selected outcome, revealed artwork URL, placement state, or the API's account-derived disk cache. `MosaicLibraryStore.refresh()` keeps its old list on failure. If user B signs in after user A and the next refresh fails or is delayed, user A's event summaries/details can remain visible in memory and potentially on screen.

**Recommendation:** Add explicit `clearPrivateState()` methods to library/detail/camera/API caches. Call them before session sign-out, account deletion, and whenever the authenticated user ID changes. Clear old collections before a new-account refresh and add an A→sign-out→B regression test with a failed B refresh.

### 3.2 [Medium] Detail loads can commit stale results

**Evidence:** `MosaicV3/Stores/MosaicDetailStore.swift:27-41`  
**Confidence:** Medium

`load(id:)` assigns whatever request finishes to the single `event` property without verifying that the response still matches the active route. Fast navigation between events can allow an older request to overwrite a newer selection if the underlying client does not cooperate with cancellation.

**Recommendation:** Track a load generation or requested event ID and only commit matching results. Clear the prior event at the appropriate transition, and test out-of-order responses.

### 3.3 [Medium] Recap export has no cooperative cancellation

**Evidence:** `MosaicV3/Infrastructure/PhotoRecapRenderer.swift:34-80`, `MosaicV3/Features/Recap/PhotoRecapBuilderView.swift:222-229`  
**Confidence:** High

The frame loop waits and encodes without `Task.checkCancellation()`. The view creates an unstructured `Task` from the button and does not retain/cancel it on disappearance. A user leaving a 24-photo render can leave expensive CPU, memory, disk, and thermal work running.

**Recommendation:** Retain the render task, cancel it when requested/on disappearance, check cancellation between photos and frames, cancel the writer, and remove partial temporary files.

## 4. Modern API Usage

### 4.1 [Medium] AVFoundation configuration and session start/stop run on the main actor

**Evidence:** `MosaicV3/Infrastructure/CameraCaptureController.swift:22-47,70-81`  
**Confidence:** High

`CameraCaptureController` is `@MainActor`, so `configure()`, `startRunning()`, and `stopRunning()` execute on the main executor. Session start can block. Camera entry and exit can therefore stall animation or trigger Thread Performance Checker warnings.

**Recommendation:** Own the capture session on a dedicated serial executor/queue. Marshal only observable UI state and photo results to `MainActor`. Verify entry, background/foreground, interruption, and denial flows on a physical device.

### 4.2 [Low] Camera preview orientation is implicit

**Evidence:** `MosaicV3/Infrastructure/CameraCaptureController.swift:85+`  
**Confidence:** Medium

The preview layer receives the session but no explicit rotation coordinator/orientation update. The app is portrait-only today, which reduces impact, but device rotation, multitasking, or future orientation support can produce incorrect framing or capture metadata.

**Recommendation:** Make portrait intent explicit and use modern AVFoundation rotation coordination if supported orientations expand.

## 5. Data Flow and State Management

### 5.1 [Remediated High] Event Pass retries did not reuse an idempotency key

**Evidence:** `MosaicV3/Stores/MosaicLibraryStore.swift:29-38`  
**Confidence:** High

Every premium create attempt calls `createPremiumMosaic` with a newly generated `UUID`. Server idempotency can protect repeated calls only when the client repeats the same ID. If the server creates an event or consumes a pass but the response is lost, a user retry uses a new ID and can duplicate work or spend another pass.

**Recommendation:** Generate and persist a request ID in the creation draft/coordinator before the first network call. Reuse it across all automatic and user retries until success or explicit abandonment. Add a test where the first request succeeds server-side but returns a simulated transport error.

### 5.2 [Medium] Failed refresh preserves stale library content

**Evidence:** `MosaicV3/Stores/MosaicLibraryStore.swift:18-26`  
**Confidence:** High

On refresh failure the store sets a message but leaves the previous array. This can be useful offline behavior for the same account, but it is unsafe across account changes and visually ambiguous when server data is stale.

**Recommendation:** Associate cached state with a user ID and last-updated timestamp. Clear on identity change, display an explicit offline/stale state, and provide retry.

### 5.3 [Medium] Recap projects are transient view state

**Evidence:** `MosaicV3/Features/Recap/PhotoRecapBuilderView.swift:9-29`  
**Confidence:** High

Selection, order, template, music, and trim are stored only in the view. Navigation away, termination, or memory pressure discards the work without warning.

**Recommendation:** Persist draft projects by event ID, autosave after meaningful edits, and offer Resume/Discard. At minimum, warn before leaving a non-empty unsaved project.

### 5.4 [Low] Configuration failure degrades into a misleading network state

**Evidence:** `MosaicV3/Stores/MosaicAppModel.swift:22-34`  
**Confidence:** High

Missing Supabase configuration creates a client for `https://invalid.local` with an invalid key. This avoids a crash but converts a configuration defect into generic network/auth failures.

**Recommendation:** Represent configuration as an explicit unavailable state with a clear diagnostic in non-production builds and a user-safe service-unavailable state in production.

## 6. Security and Privacy

### 6.1 Security impact of finding 3.1

This is the security consequence of finding 3.1. Event names, membership context, kindness notes, contributor display names, photo authorship/times, and local protected image files are account-scoped. Resetting the navigation stack is not equivalent to erasing the model and cache.

**Recommendation:** Treat authentication changes as a privacy boundary. Clear all account-derived memory and disk state before presenting signed-out UI. Consider namespacing caches by authenticated user and applying an eviction policy.

### 6.2 [Remediated Medium] Photo report/block/delete actions executed without confirmation or reason selection

**Evidence:** `MosaicV3/Features/Mosaics/PhotoGalleryView.swift:73-95`  
**Confidence:** High

One tap immediately deletes the user's photo, reports another photo with a hard-coded reason, or blocks its photographer. The lack of confirmation increases accidental destructive action; the hard-coded report reason provides poor moderation signal.

**Recommendation:** Add `confirmationDialog` for destructive actions, a concise report reason picker plus optional detail, and a clear explanation of block consequences. Keep report and block distinct.

### 6.3 [Medium] Account-derived disk caches have no visible lifecycle/eviction boundary

**Evidence:** `MosaicV3/Infrastructure/SupabaseMosaicAPI.swift:213-228` and artwork reveal-cache implementation  
**Confidence:** Medium

Gallery and revealed-artwork files are written with file protection, which is good, but the reviewed flows do not establish bounded eviction or sign-out deletion.

**Recommendation:** Namespace by account, clear on sign-out/delete, cap total size and age, and document which revealed public artwork may safely persist independently.

### 6.4 [Low] Custom-scheme invitations lack origin assurance

**Evidence:** `MosaicV3/Stores/MosaicAppModel.swift:81-85`, `project.yml:34-37`  
**Confidence:** Medium

The app accepts `mosaic://join/<code>` and registers only a custom scheme. Custom schemes can be claimed by another installed app and offer no associated-domain trust or web fallback.

**Recommendation:** Use HTTPS universal links with Associated Domains and retain the custom scheme only as a controlled fallback. Validate host/path and normalize invitation codes defensively.

## 7. Performance and Memory

### 7.1 [High] Event loading eagerly downloads every full gallery photo sequentially

**Evidence:** `MosaicV3/Infrastructure/SupabaseMosaicAPI.swift:213-228`  
**Confidence:** High

`hydratePhotos(in:)` runs before returning the event, creates local URLs, and serially downloads each missing full image. With many members and up to dozens of photos per person, opening an event can take a long time, fail because one asset fails, use substantial storage, and delay non-photo content that was already available.

**Recommendation:** Return event metadata immediately. Fetch thumbnails lazily per visible cell, use bounded concurrency and per-photo failure states, request appropriately sized images, and prefetch only near-visible items. A single photo failure must not fail the event.

### 7.2 [Medium] Recap rendering decodes full image files on the render actor

**Evidence:** `MosaicV3/Infrastructure/PhotoRecapRenderer.swift:60-74`  
**Confidence:** High

Each source is loaded with `Data(contentsOf:)` and decoded to `UIImage`, then repeatedly drawn into 1080×1920 buffers. Although only one `UIImage` is retained per outer iteration, large camera images and 30 fps rendering create avoidable memory, decode, and thermal pressure.

**Recommendation:** Downsample with ImageIO to the maximum render size, use autorelease pools around frame work, measure peak RSS/thermal behavior, and avoid redundant transforms.

### 7.3 [Medium] Gallery cache has no size-aware thumbnail strategy

**Evidence:** `MosaicV3/Infrastructure/SupabaseMosaicAPI.swift:215-226`, `MosaicV3/Features/Mosaics/PhotoGalleryView.swift:42-55`  
**Confidence:** High

Full downloaded images back a small three-column grid. The UI does not request or persist fit-for-purpose thumbnails, so network, storage, and decoding cost exceed what the grid needs.

**Recommendation:** Generate/server-deliver thumbnails, preserve originals for detail/export only, and measure scrolling with the maximum supported event/photo population.

## 8. SwiftUI UX and Accessibility

### 8.1 [Medium] Success and error feedback share the same red presentation

**Evidence:** `MosaicV3/Features/Mosaics/KindnessViews.swift:34,62-70`, `MosaicV3/Features/Recap/PhotoRecapBuilderView.swift:61,231-239`  
**Confidence:** High

“Note saved,” “Contribution withdrawn,” and “Saved to Photos” are displayed in red because one string property represents both success and failure. This makes successful actions feel dangerous and weakens color semantics.

**Recommendation:** Introduce a typed feedback state (`success`, `error`, `info`) with icon, text, color-independent semantics, and appropriate accessibility announcements.

### 8.2 [Medium] Six-stage creation lacks persistent context and recovery

**Evidence:** `MosaicV3/Features/Mosaics/CreateMosaicView.swift`  
**Confidence:** High

The stage sequence is logical, but organizers must retain the meaning of artwork, goal, film, timing, premium capacity, and invite outcome across six screens. There is no persistent guest preview, templates, or visible draft recovery.

**Recommendation:** Add a compact live summary/preview, presets for common occasions, explicit progress, autosave status, and a final validation list that links back to incomplete sections.

### 8.3 [Medium] Only four artworks are exposed despite a larger reviewed catalog

**Evidence:** `MosaicV3/Domain/MosaicModels.swift:48-53`, creation artwork picker, `supabase/catalog/artic-museum-artworks.v1.json`  
**Confidence:** High

The shipping picker is hard-coded to four works while 112 catalog records exist. This is not a correctness bug, but it limits repeat-event variety and makes the backend investment invisible.

**Recommendation:** Keep the four-item claim honest for submission. Later connect a curated catalog endpoint with search/filtering, attribution, alt text, license review, offline/reveal packaging, and deterministic fallback.

### 8.4 [Low] Invitation navigation has no install-free path

**Evidence:** `MosaicV3/Stores/MosaicAppModel.swift:81-85`, `project.yml:34-37`  
**Confidence:** High

A custom scheme works only when the app is installed and correctly associated. A recipient otherwise sees no useful preview or install continuation.

**Recommendation:** Add a branded HTTPS invitation page, universal link, App Store continuation, and deferred code entry after installation/sign-in.

### 8.5 [Low] Recap ordering is accessible but inefficient for large selections

**Evidence:** `MosaicV3/Features/Recap/PhotoRecapBuilderView.swift:93-117`  
**Confidence:** High

Move earlier/later buttons are explicit and accessible, but reordering 24 items is tedious. There is no drag gesture or jump-to-position alternative.

**Recommendation:** Preserve accessible buttons, add drag reordering for pointer/touch users, and announce final positions.

## 9. Code Quality and Maintainability

### 9.1 [Low] User feedback is represented by untyped strings in multiple stores/views

**Evidence:** `MosaicLibraryStore.message`, `MosaicDetailStore.message`, recap/kindness/gallery view state  
**Confidence:** High

The same string channel carries validation, network errors, success, warnings, and announcements. This causes the red-success defect and makes retry behavior inconsistent.

**Recommendation:** Introduce a small shared `UserFeedback` value with severity, message, recovery action, accessibility behavior, and optional stable identifier.

### 9.2 [Low] Large feature files combine orchestration and presentation

**Evidence:** `MosaicV3/Features/Recap/PhotoRecapBuilderView.swift`, camera feature, create feature, debug showcase fixture  
**Confidence:** Medium

The files remain understandable, but multi-stage state machines, preview rendering, row/card presentation, and side effects are colocated. This raises regression risk as polishing continues.

**Recommendation:** Extract stage-specific views and a recap/create coordinator or model while preserving domain/store/infrastructure boundaries. Keep refactoring behavior-neutral and covered by focused tests.

### 9.3 [Low] Legal/support URL definitions are duplicated

**Evidence:** Paywall and account feature destinations  
**Confidence:** Medium

Duplicated URLs can drift between paywall, account, review metadata, and website.

**Recommendation:** Centralize public destinations in typed app configuration and add a release contract test for reachability/expected host.

## 10. Testing Gaps

1. Add an identity-boundary test: user A loads private events/photos, signs out, user B signs in, B refresh fails, and no A data remains.
2. Add a premium-create uncertain-response test proving the same idempotency key is reused and only one pass/event is consumed.
3. Add out-of-order detail-load tests.
4. Add maximum-gallery tests with failed/missing photos and prove non-photo event content appears immediately.
5. Add recap cancellation, low-storage, backgrounding, thermal, 24-photo, and source-file-disappears tests.
6. Add physical-device camera tests for first permission, denial/recovery, interruptions, background/foreground, rapid enter/exit, and low light.
7. Add confirmation/report-reason UI tests for photo safety actions.
8. Add universal/deferred-link tests once HTTPS invitations exist.
9. Add a production-like RevenueCat test matrix: purchase success, user cancel, pending, network loss after server success, restore, expiration, account switch, and Event Pass depletion.
10. Run the remaining UI journeys and distribution checks on the exact commit; the clean current-source unit build now passes.

## 11. Prioritized Remediation Plan

### P0 — before production App Store release

1. ~~Clear all account-derived memory and disk state on identity change/sign-out/delete.~~ Completed and tested.
2. ~~Persist Event Pass request IDs across uncertain create retries.~~ Completed and tested.
3. Replace eager full-gallery hydration with lazy thumbnails and isolated per-photo failures.
4. Materialize all source files and complete a clean full build/test/archive on the exact release commit.
5. Verify production RevenueCat/App Store products, purchase/restore, entitlements, export compliance, privacy answers, reviewer metadata, and processed build.

### P1 — next tested patch

1. Move AVFoundation session operations off `MainActor`.
2. Make recap rendering cancellable and downsample source images.
3. ~~Add destructive confirmations and report reasons.~~ Completed; UI automation remains.
4. ~~Type feedback states and correct success presentation.~~ Completed.
5. Guard detail loads against stale responses.
6. Persist recap/create drafts.

### P2 — product hardening

1. Universal-link invitation funnel.
2. Cache quotas, expiry, account namespace, and instrumentation.
3. Expand the curated artwork picker safely.
4. Split large multi-stage views after behavior is covered.
5. Run observed usability and maximum-scale performance studies.

## 12. App Store Review Checklist Results

| Section | Result | Evidence / remaining work |
|---|---|---|
| 1.1 App completeness | WARN | Core flows exist; final device/backend/purchase journey not freshly verified |
| 1.2 Accurate metadata | WARN | Draft exists; App Store Connect values and public repo story need alignment |
| 1.3 In-app purchase | FAIL | Production App Store product configuration and successful purchase/restore are not proven |
| 1.4 Hardware compatibility | WARN | Portrait iPhone app; physical camera/device matrix still needed |
| 1.5 Software requirements | PASS | iOS 18 target and supported SDK structure are explicit |
| 1.6 Data security | PASS/WARN | Account-state/cache clearing is fixed and tested; cache quotas/expiry remain hardening work |
| 1.7 Privacy policy and manifest | WARN | Files/links exist; final privacy answers and generated report need verification |
| 1.8 User-generated content | PASS/WARN | Report/block/delete now include confirmation and report reasons; final device/VoiceOver verification remains |
| 2.1 Performance | FAIL | Eager gallery downloads, main-actor camera session, and recap resource issues require scale/device proof |
| 2.2 Business model clarity | PASS | Host-paid, participants-free model and purchase surfaces are understandable |
| 2.3 Sign in with Apple | PASS | Present as the primary sign-in method; account deletion exists |
| 2.4 Legal/compliance | FAIL | Export-compliance and final App Store Connect legal answers are incomplete |
| 2.5 Distribution readiness | FAIL | Distribution archive/upload/processed build is not proven |
| 2.6 Review information | WARN | Reviewer notes, contact, demo access/video, and backend availability need final confirmation |

### Bottom line

The app is a credible hackathon submission now. The identity boundary and billing retry idempotency are closed; production release safety still depends on gallery loading, camera/recap performance, and external App Store configuration. The correct submission-day move is to publish the current V3 story, capture a reliable judge path, and avoid introducing untested feature scope.
