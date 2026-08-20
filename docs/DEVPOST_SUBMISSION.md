# Devpost submission copy

## Project name

Mosaic

## Tagline

Small acts. One shared story.

## Track

App Development

## One-line description

Mosaic turns privately verified acts of kindness into one equal-weight collaborative ceramic artwork, revealed together without rankings, likes, or public profiles.

## Inspiration

Kindness often disappears into private moments, while social products tend to make participation visible through points, streaks, likes, or leaderboards. We wanted a shared experience that could make community care tangible without turning generosity into performance. A mosaic gave us the right metaphor: every contribution matters, every tile has equal visual weight, and the final image belongs to the group.

## What it does

An invited group joins a kindness challenge anonymously, chooses a mission, and submits a reflection or private evidence. Organizers review evidence without exposing it to the group. Accepted acts become equal-size ceramic tiles, and private Realtime invalidations keep each member's mosaic synchronized. When the challenge ends, the group opens a coordinated reveal containing the final artwork, only the memories participants approved, an attributable Impact Receipt, and an on-device vertical recap.

Mosaic separates evidence review from community-story consent. Participants independently control whether a memory is included, whether their name appears, and whether it may enter an exported recap. There are no likes, follower counts, public profiles, or larger tiles for paid users.

## How we built it

The iOS app uses Swift 6, SwiftUI, Observation, AVFoundation, WidgetKit, ActivityKit, UserNotifications, EventKit, and StoreKit-compatible RevenueCat infrastructure. Supabase provides anonymous authentication, Postgres, Row Level Security, private Storage, Realtime, Edge Functions, and scheduled reveal jobs.

The client performs RLS-filtered reads, while authenticated Edge Functions authorize lifecycle changes such as submission, moderation, placement, and reveal. Evidence, ownership, consent, approved memories, and abstract tile state are stored separately. Realtime broadcasts only sanitized invalidation identifiers; clients refetch canonical state. The recap engine renders consent-aware 1080 x 1920 H.264/AAC videos entirely on device.

## Challenges we ran into

The hardest problem was making privacy part of the data model instead of a single toggle. Evidence can be valid for organizer review while still being excluded from the community story. We also had to make concurrent tile placement deterministic, keep Realtime payloads free of sensitive data, produce a reliable vertical recap under device storage constraints, and preserve a judgeable experience when a hosted backend is unavailable.

## Accomplishments we are proud of

- Equal visual weight with no competitive engagement mechanics.
- Separate evidence, identity, memory, and export consent.
- Membership-scoped RLS, private Storage, and narrow server-authorized mutations.
- Atomic tile placement and synchronized reveals.
- A deterministic, consent-aware on-device recap renderer.
- Accessibility support for VoiceOver, Dynamic Type, Reduce Motion, and non-color states.
- A hosted synthetic judge environment plus a credential-free offline showcase.
- Reproducible simulator screenshots and a comprehensive automated test suite.

## What we learned

Trustworthy collaboration depends on treating privacy, retries, authorization, and failure recovery as product behavior. We learned to use Realtime as a minimal invalidation channel rather than a source of truth, to encode lifecycle invariants in both Postgres and Edge Functions, and to keep the emotional payoff of a reveal while removing competitive pressure.

## What's next

After the hackathon we will complete the billing-enabled App Store release: RevenueCat products, sandbox purchase and restore testing, production push delivery, and full App Review. The hackathon build already supports optional native Sign in with Apple and is prepared for TestFlight distribution. We also plan to explore partner confirmation, richer organizer reporting, and additional accessible artwork systems while preserving equal-weight participation.

## Built with

Swift, SwiftUI, Observation, AVFoundation, WidgetKit, ActivityKit, EventKit, UserNotifications, Supabase Auth, PostgreSQL, Row Level Security, Storage, Realtime, Edge Functions, Deno, pgTAP, RevenueCat, XcodeGen, GitHub Actions, and GitHub Pages.

## Submission links

- Source repository: https://github.com/shellcat-com/Mosaic
- Project documentation: https://github.com/shellcat-com/Mosaic/blob/main/Mosaic-Reverie-Documentation.md
- PDF documentation: https://github.com/shellcat-com/Mosaic/releases/download/reverie-2026/Mosaic-Reverie-Documentation.pdf
- Demo video: https://github.com/shellcat-com/Mosaic/releases/download/reverie-2026/Mosaic-Reverie-Demo.mp4
- Privacy Policy: https://shellcat-com.github.io/Mosaic/privacy/
- Terms of Use: https://shellcat-com.github.io/Mosaic/terms/

## Screenshot selections

1. Collaborative Living Kiln home mosaic.
2. Mission evidence options and privacy explanation.
3. Independent consent controls.
4. Equal-weight tile placement.
5. Final reveal, approved memories, and Impact Receipt.

Use the five validated images under `design/marketing/app-store/` or the combined repository gallery at `design/marketing/repository/mosaic-app-store-gallery.png`.
