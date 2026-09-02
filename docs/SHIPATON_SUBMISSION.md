# RevenueCat Shipaton 2026 — Mosaic

**Primary category:** Next Gen Award

**Project:** Mosaic

**Tagline:** Small acts. One shared story.

Select **Next Gen only** unless Mosaic later receives its first supported-store release during the submission window.

## One-line description

Mosaic turns small acts of kindness into one equal-weight collaborative ceramic artwork a private group reveals together—without rankings, likes, or pay-to-win visibility.

## Inspiration

Kindness often disappears into private moments, while social products make participation visible through scores, streaks, and leaderboards. A mosaic offered a gentler metaphor: every contribution matters, every tile has the same visual weight, and the finished story belongs to the group.

## What it does

An organizer creates a time-limited Mosaic with approachable kindness activities, reviewed public-domain artwork, a disposable-film look, a shot limit, and a fixed reveal time. Members join by invitation, complete each activity at most once, and place one equal-size tile. The photo-only disposable roll is separate: retakes are free, kept frames consume a shot, and members see only their own sealed photos before reveal. At reveal, the group receives the artwork, readable Kindness side, eligible gallery, and an optional on-device photo recap.

Participants remain completely free. Payment never changes tile size, visibility, attribution, joining, reveal access, gallery access, or recap access.

## RevenueCat and monetization

Free organizers can run one unrevealed Mosaic at a time with 9, 16, or 25 tiles, 12 shots per member, and the Sunwashed film look. Organizer Plus unlocks multiple active Mosaics, 36–100 tile goals, 24 or 36 shots, and all film looks. A one-event pass unlocks the same premium event choices for one Mosaic by granting one `PASS`.

The custom SwiftUI “Make room for more people” Living Kiln paywall loads annual, monthly, and Event Pass data from RevenueCat offering `organizer_plus_v1`; it never hardcodes prices, trials, renewal language, or savings. Monthly and annual products unlock entitlement `organizer_plus`. Product `mosaic_event_pass_v2` grants virtual currency `PASS`.

RevenueCat uses the lowercase Supabase UUID as `appUserID`. Purchases and restores may show optimistic progress, but premium choices unlock only after an authenticated Edge Function reconciles RevenueCat API v2 into the server snapshot. PASS spending is server-initiated, idempotent, and resumable. Each Mosaic captures `free`, `organizer_plus`, or `event_pass` when created, so expiry never damages an existing event.

## How we built it

The iPhone app uses Swift 6, SwiftUI, Observation, AVFoundation, Sensitive Content Analysis, PhotoKit, RevenueCat Purchases, and Supabase Swift. Supabase provides Sign in with Apple sessions, Postgres, Row Level Security, private Storage, Edge Functions, and scheduled reveal jobs. Photos are permanently developed on device; recap videos render locally. RevenueCat public SDK keys stay in the client, while secret/V2 keys and webhook authorization remain server-side.

## Challenges

The hardest boundary was making monetization useful to organizers without changing the participant experience. The client needed a delightful purchase ceremony, while the database still had to reject free-limit bypasses, stale subscriptions, replayed webhooks, double PASS debit, and cross-user attempts. The same principle shaped privacy: aggregate tile progress can be visible before reveal while identities, notes, photos, and artwork stay sealed.

## Why Next Gen

Mosaic is a complete student-built product spanning product thesis, original Living Kiln design, accessible SwiftUI, RevenueCat Test Store integration, server-authoritative monetization, private media architecture, automated Swift/Deno/pgTAP tests, and a public open-source reproduction path. The final genuine purchase recording remains a submission gate.

## Links

- Source: https://github.com/shellcat-com/Mosaic
- Privacy: https://shellcat-com.github.io/Mosaic/privacy/
- Terms: https://shellcat-com.github.io/Mosaic/terms/
- Demo video: **ADD PUBLIC YOUTUBE OR VIMEO URL AFTER THE NEW V3 RECORDING**

## Required media

- Icon, 1024×1024: `Mosaic/Resources/Assets.xcassets/AppIcon.appiconset/MosaicAppIcon.png`
- Main frameless V3 screenshot, 1179×2556: `submission/Mosaic-Shipaton-Screenshot-1179x2556.png`
- Additional custom-paywall gallery image: `submission/Mosaic-Shipaton-Paywall.png`
- Optional active-event gallery image, 1179×2556: `submission/Mosaic-Shipaton-Active-1179x2556.png`
- Optional revealed-artwork gallery image, 1179×2556: `submission/Mosaic-Shipaton-Reveal-1179x2556.png`
- Captioned demo, under two minutes: `submission/Mosaic-Shipaton-Demo.mp4`

## Final checklist

- Confirm every official team member is an active student with a qualifying academic email.
- Record a genuine monthly or annual Test Store purchase, server-confirmed Plus, and unlocked 100-tile choice.
- Complete monthly, annual, Event Pass, restore, relaunch, cancellation, pending, and insufficient-PASS checks.
- Keep the verified current V3 screenshot/paywall captures; replace the 97-second legacy video with the genuine 100–110 second V3 recording and verify its duration.
- Push the complete V3 target, shared scheme, tests, migrations, assets, MIT license, and current README to public `main`.
- Verify source, license, video, privacy, and terms while signed out.
- Join the hackathon, create the Devpost draft, populate every required field, and select Next Gen only.
- Run `./scripts/validate_shipaton_submission.sh --final` immediately before submission.
