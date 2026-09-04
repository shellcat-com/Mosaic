# Mosaic — Current Hackathon Submission Plan

## Decision

The attached “Corrected 10/10 Hackathon Plan” remains useful for Mosaic’s core
experience, but its implementation baseline and monetization section are no
longer authoritative. This plan follows the current working tree, preserves the
implemented v3 experience, and separates locally complete work from external
submission gates.

Mosaic’s judge path remains:

> Join an invited group, complete a self-attested kindness activity, watch one
> equal server-assigned tile join the board, capture separate disposable photos,
> experience the fixed reveal, explore Artwork/Kindness/Photos, and make a
> personal photo-only recap.

## Product contracts that remain locked

- Sign in with Apple and a display name are required before joining.
- Membership is invitation-only; there is no anonymous mode or privacy selector.
- Each participant may complete each organizer-created activity once.
- Contributions are self-attested and equal: no evidence, approval, points,
  rankings, or organizer moderation settings.
- The server assigns tile positions atomically. Placement is automatic; people
  never drag tiles or choose positions.
- Photos are captured only in Mosaic’s photo-only camera. They never create tiles
  and never act as proof.
- The reveal occurs at the fixed time and completes the artwork even if the board
  did not fill.
- Revealed outcomes stay separate: Artwork, Kindness, and Photos.
- Recaps accept only 1–24 selected `EventPhoto` values, preserve participant
  ordering, and render every selected photo exactly once.
- Recaps contain no artwork, title/ending card, activity, note, contributor,
  caption, statistic, or impact receipt.
- Existing templates, music, trimming, and 1080×1920 recap export remain part of
  the participant experience.
- No hosted destructive migration or RevenueCat dashboard mutation is performed
  without explicit authorization.

## Current verified baseline — August 31, 2026

- The focused `MosaicV3` app and both test targets build successfully with Swift 6.
- 46 Swift tests pass across 12 suites, including account-bound cleanup, Event Pass retry idempotency, private media cleanup, and light/dark primary, accent, and secondary foreground-contrast regressions.
- The real 24-photo 1080×1920 recap render passes and preserves all selections.
- All 15 UI tests pass together on a clean iPhone 15 Pro simulator at standard text
  size.
- Maximum Dynamic Type tests pass for the adaptive recap stage control and the
  simplified disposable-camera layout.
- The 100-tile reveal and its Reduce Motion path pass.
- Account deletion, deep-link joining, creation, placement, camera review, recap
  editing/playback, and current RevenueCat showcase states pass UI automation.

## Completed implementation

### Submission-day flow polish

- Creation offers three editable quick starts, keeps a live guest-outcome summary visible, and restores the current draft and step within the signed-in session.
- Recap restores in-session edits, previews each included music track from the selected trim point, estimates output duration, confirms reset, and cancels active frame/export work.
- Creative drafts are account-bound private state and are cleared by sign-out, deletion, and identity changes.
- Gallery hydration now uses bounded groups of four protected downloads instead of a fully serial pipeline.
- AVFoundation session configuration/start/stop runs on a dedicated serial queue and retries when the app returns to the foreground.

### Core hierarchy and navigation

- One typed router owns tabs, paths, invitations, camera destinations, and
  private-state reset.
- Home and active Mosaic screens lead with the next meaningful action.
- Create, Join, activity, camera, reveal, gallery, recap, and account journeys are
  represented by deterministic showcase routes.

### Signature Mosaic moments

- Contribution confirmation receives the immutable assigned tile before the
  automatic placement ceremony begins.
- Placement supports Skip, explicit Continue, success feedback, and a Reduce
  Motion completion path.
- Reveal playback turns contributed positions first, completes remaining
  porcelain positions, stays bounded at 100 tiles, and does not mix photos into
  the artwork outcome.
- Camera review exposes Keep and Retake; retakes do not spend an exposure.
- The sealed-roll explanation remains visible before reveal.
- Recap editing keeps photo selection, order, templates, music, preview, render,
  and export separate from kindness and artwork.

### Accessibility and responsive UI

- The camera and placement ceremony expose native sensory feedback and announced
  status instead of manually constructed UIKit haptics.
- Placement animation respects Reduce Motion.
- At Accessibility XXXL, the recap segmented control becomes a menu.
- At Accessibility XXXL, oversized decorative camera hardware labels collapse
  into readable Mosaic, film-look, and shots-remaining summaries.
- The normal-size camera retains Mosaic’s tactile disposable-camera personality.
- UI tests are main-actor isolated and compile without Swift concurrency warnings.
- A dedicated semantic accent keeps text, symbols, links, progress, and focus rings readable in both appearances while preserving the darker ceramic glaze for material fills.
- The revealed-event UI test now waits for the finished artwork state and verifies that temporary opening copy is gone.
- XCTest's system accessibility audit passes across Home, Create, active and
  revealed Mosaics, Camera, and Recap for hit regions, element descriptions,
  traits, clipping, and other supported checks. Dynamic Type has dedicated XXXL
  journeys, while contrast is independently enforced by deterministic palette
  tests because XCTest's pixel audit is unreliable with the custom display font.

## Monetization decision gate

The repository currently implements a RevenueCat Shipaton track with Organizer
Plus subscriptions and Event Passes. It gates organizer creation choices such as
larger boards, higher shot limits, and additional film looks while unit tests
verify that participant access is never restricted.

This differs from both earlier directions:

1. the original free App Store v1 contract with no RevenueCat; and
2. the attachment’s keepsake-only `$4.99` non-consumable, which would not gate
   creation choices.

Do not combine these stories in submission materials. Before final screenshots,
video, App Store copy, or hosted billing configuration, choose exactly one:

- **Current Shipaton track:** subscriptions + Event Pass, matching the current
  app, tests, README, architecture, and Shipaton documents.
- **Keepsake-only track:** remove subscription/pass gating and redesign billing
  around a separate print export.
- **Free App Store track:** remove RevenueCat and all paid surfaces.

Until that choice is explicit, preserve the current RevenueCat work and do not
rewrite it into a different model.

## Remaining submission sequence

1. Choose and lock the monetization track; update every public claim to match it.
2. Run current local Supabase reset/lint/pgTAP checks and record the actual count;
   do not reuse the attachment’s stale count.
3. Verify live Sign in with Apple, camera permission, sensitive-content analysis,
   offline photo retry, purchase/restore if retained, and photo saving on an
   unlocked physical iPhone.
4. Audit VoiceOver with Screen Curtain, Voice Control, Bold Text, Increase
   Contrast, Differentiate Without Color, Smart Invert, Reduce Transparency, and
   Reduce Motion on device.
5. If the hosted v3 backend still requires destructive deployment, back it up and
   obtain explicit authorization before applying it.
6. Capture final screenshots only from the exact release source and chosen
   monetization track.
7. Reconcile README, architecture, Shipaton copy, App Store disclosures, privacy
   manifest, Terms, support, community guidelines, demo script, and reviewer
   notes.
8. Produce and validate the distribution archive, then complete the relevant
   submission portal fields and reviewer credentials.

## Completion rule

Local implementation is strong and its automated judge path is green, but Mosaic
is not honestly “submission complete” until the monetization story is singular,
live service/device checks pass, any authorized hosted backend work is verified,
and the exact distribution build and public materials all describe the same app.
