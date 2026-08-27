# App Store disclosures — Mosaic v1

## Product and account

- Participants join and use every Mosaic for free. Organizers may purchase Mosaic Plus subscriptions or a one-event Event Pass through Apple's in-app purchase system; there are no external purchase links.
- Sign in with Apple and a 2–40 character display name are required.
- Account deletion is available in **You → Delete account**.
- Invitation-only events; there is no discovery feed, anonymous participation, or configurable privacy mode.

## User-generated content and safety

- Organizers create event names, descriptions, and kindness activities.
- Members create optional contribution notes and camera photos.
- On-device Sensitive Content Analysis runs before a developed JPEG is uploaded.
- Every photo detail provides Report; a report immediately quarantines the photo from gallery and recap queries.
- Every non-owner photo provides Block; blocking hides that contributor's photos for the blocker.
- Photographers may delete their photos, creators may delete their Mosaic, and all users can contact published support.
- There is no organizer approval queue. Developer review of reports is an operational safety function, not a configurable event setting.

## Permissions

| Permission | Reason |
| --- | --- |
| Camera | Capture still photos for an event's disposable roll. |
| Add Photos only | Save a participant's locally rendered recap. |
| Sign in with Apple | Required recoverable account identity. |

The app does not request microphone, Photo Library read, contacts, location, notification, calendar, tracking, or advertising permissions.

## Export compliance

Mosaic uses CryptoKit AES-GCM to decrypt the organizer-selected artwork package only after the fixed reveal. The app therefore declares `ITSAppUsesNonExemptEncryption = YES` conservatively. Before upload, complete App Store Connect's export-compliance questionnaire and attach any classification or exemption documentation Apple requests. Do not change the declaration to `NO` merely because ordinary network transport also uses HTTPS.

## App Privacy answers

Data linked to the account and used only for app functionality:

- Name / display name.
- Email address supplied by Sign in with Apple, including Apple's private relay address when chosen.
- User ID.
- Photos.
- Other user content: event text, activities, and optional notes.

Purchase history is linked to the account and used for app functionality and RevenueCat subscription analytics. It is not used for tracking.

Mosaic does not track users, sell data, serve ads, or use data for third-party advertising. Supabase provides authentication, database, private storage, and server operations. RevenueCat validates purchases, reconciles entitlements, and provides subscription analytics. Apple provides Sign in with Apple, in-app purchase, and add-only Photos access.

## Purchases

- Mosaic Plus is offered monthly and annually; an Event Pass applies to one newly created premium Mosaic.
- Prices, periods, renewal terms, and any introductory offer are loaded from the App Store through RevenueCat and are not hardcoded.
- Participants are never charged and existing event access is not removed if an organizer's subscription later expires.
- Restore Purchases and subscription-management access appear on the native purchase screen. The privacy policy and Terms are linked from that screen.

## Review notes

Review uses Apple's native Sign in with Apple sheet; no developer password is required. The reviewer can create a Mosaic, share its `mosaic://join/CODE` invitation, complete one activity, and capture a photo on a physical test device. Fixed reveal behavior is server-timed. Review notes must include one pre-created invitation whose reveal occurs during the review window and one already-revealed invitation so Artwork, Kindness, Photos, reporting, blocking, and Recap can be inspected without waiting.
