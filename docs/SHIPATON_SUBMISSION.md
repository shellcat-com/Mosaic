# RevenueCat Shipaton 2026 submission

## Project

**Name:** Mosaic

**Tagline:** Small acts. One shared story.

**Primary category:** Next Gen Award

**Add only after an eligible store release:** RevenueCat Peace Prize, RevenueCat Design Award

> Next Gen is the only category that does not require a public App Store,
> Google Play, or Galaxy Store listing. Devpost staff have confirmed that a
> student may enter Next Gen and other categories together, but the app must be
> published to a supported store during the submission period to qualify for
> those other categories. Until a store URL is live, select **Next Gen only**.

## One-line description

Mosaic turns privately verified acts of kindness into one equal-weight collaborative ceramic artwork, revealed together without rankings, likes, or public profiles.

## Inspiration

Kindness often disappears into private moments, while social products make participation visible through points, streaks, likes, and leaderboards. We wanted a shared experience that could make community care tangible without turning generosity into performance. A mosaic is the right metaphor: every contribution matters, every tile has equal visual weight, and the finished story belongs to the group.

## What it does

An invited group joins a time-limited kindness challenge, chooses an approachable mission, and submits a reflection or private evidence. Organizers review evidence without exposing it to the community. Accepted acts become equal-size ceramic tiles. When the challenge ends, the group opens a coordinated reveal with the final artwork, only the memories participants approved, an attributable Impact Receipt, and an on-device vertical recap.

Mosaic separates evidence review from community-story consent. Participants independently control memory inclusion, identity display, and recap/export consent. There are no likes, follower counts, public profiles, leaderboards, or larger tiles for paying users.

## RevenueCat and monetization

Participants contribute equally for free. Organizers can purchase Organizer Plus for larger events, custom artwork, trusted collaborators, recap approval, and presentation-quality exports. Monthly and annual subscriptions unlock the `organizer_plus` entitlement, while a non-expiring Mosaic Pass can fund one premium event.

The app uses RevenueCat Paywall V2, purchase and restore handling, CustomerInfo identity tied to the organizer’s Supabase UUID, authenticated server refresh, webhook synchronization, and idempotent virtual-currency redemption. Paid features support organizers without assigning greater visual importance to anyone’s act.

## How we built it

The iOS app uses Swift 6, SwiftUI, Observation, AVFoundation, WidgetKit, ActivityKit, EventKit, UserNotifications, and RevenueCat. Supabase provides anonymous and Apple-linked authentication, Postgres, Row Level Security, private Storage, Realtime invalidations, Edge Functions, and scheduled reveal jobs.

Authenticated Edge Functions authorize lifecycle changes and billing refreshes. Evidence, ownership, consent, approved memories, and abstract tile state are stored separately. RevenueCat secret keys remain server-side. The recap engine renders consent-aware 1080×1920 H.264/AAC videos on device.

## Challenges

The hardest problem was making privacy part of the data model instead of a single toggle. Evidence can be valid for organizer review while still being excluded from the community story. We also had to make concurrent tile placement deterministic, keep Realtime payloads free of sensitive data, synchronize RevenueCat entitlement and PASS state without trusting the client, and preserve a judgeable experience when a hosted backend is unavailable.

## Next Gen Award

Mosaic demonstrates a complete student-built iPhone product from product thesis and visual system through a working SwiftUI client, hosted backend, automated security tests, RevenueCat purchase flow, and open-source reproduction path. The core participant, organizer, reveal, and monetization workflows are visible in the video and source repository.

## RevenueCat Peace Prize

Mosaic helps schools, neighborhoods, workplaces, nonprofits, and friend groups make community care visible without making it competitive. Private verification creates trust, equal-size tiles preserve dignity, independent consent protects participants, and the Impact Receipt distinguishes verified, confirmed, and self-attested outcomes instead of making vague impact claims.

## RevenueCat Design Award

The “Living Kiln” direction combines porcelain surfaces, tactile glazed tiles, editorial typography, restrained native controls, and motion that explains shaping, firing, placing, connecting, and revealing. Kintsugi gold appears only when a dormant kindness chain is revived. VoiceOver, Dynamic Type, Reduce Motion, Reduce Transparency, and non-color state communication are designed as first-class behaviors.

## Links

- Source: https://github.com/shellcat-com/Mosaic
- Privacy: https://shellcat-com.github.io/Mosaic/privacy/
- Terms: https://shellcat-com.github.io/Mosaic/terms/
- Store listing: **REQUIRED BEFORE SELECTING PEACE PRIZE OR DESIGN AWARD**
- Demo video: **ADD PUBLIC YOUTUBE OR VIMEO URL AFTER FINAL UPLOAD**

## Required media

- App icon: `Mosaic/Resources/Assets.xcassets/AppIcon.appiconset/MosaicAppIcon.png`
- Raw 1179×2556 screenshot: `submission/Mosaic-Shipaton-Screenshot-1179x2556.png`
- Repository gallery: `design/marketing/repository/mosaic-app-store-gallery.png`

## Final eligibility and upload checks

- Confirm every listed team member is an active student and the Devpost account
  uses a qualifying academic email before selecting Next Gen.
- Keep the GitHub repository public through judging and make the MIT license
  visible in the repository About panel.
- Push the complete Shipaton source, shared scheme, assets, and judge
  instructions to the repository's default branch before submitting its URL.
- Record a genuine RevenueCat Test Store purchase in the running iOS app.
- Upload a public YouTube or Vimeo video shorter than two minutes, paste its URL
  above, and verify it while signed out.
- Upload the 1024x1024 icon and the raw 1179x2556 screenshot without a device
  frame.
- If entering Peace Prize or Design Award, publish version 1.0 to a supported
  store during the Shipaton submission period and provide a free trial or judge
  promo code. Otherwise select Next Gen only.
- Run `./scripts/validate_shipaton_submission.sh --final` immediately before
  completing the Devpost form.
