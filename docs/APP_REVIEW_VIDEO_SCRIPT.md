# App Review video script — Mosaic 1.0

Target length: 75–100 seconds. Record the hosted invitation and real camera on
the physical iPhone in portrait. Record the deterministic revealed/paywall
scenes on an iPhone 17 Pro simulator in portrait, then combine the portrait
captures on a neutral 16:9 canvas. Label simulator-only scenes “Synthetic review
data — shipping UI” so the attachment cannot be mistaken for hosted reviewer
data. Do not show Apple credentials, API keys, private user data, or the
RevenueCat dashboard.

## Recording checklist

1. Start on **Mosaics** and enter `REVIEW26` under **Join**. Show the hosted
   invitation preview. Sign in with a dedicated Apple test account before the
   recording if the complete live join is included.
2. Open the active event. Show **Artwork**, one kindness activity, **I took
   part**, and the equal-size tile appearing on the board.
3. On the physical iPhone, open **Camera**, capture one still image, then show
   **Retake** and **Keep photo**. Mention that photos are not evidence for
   kindness. Do not substitute the simulator for this step because it has no
   physical camera feed.
4. Cut to the Debug showcase `revealed` fixture and add the “Synthetic review
   data — shipping UI” label. Show the artwork reveal, then
   switch among **Artwork**, **Kindness**, and **Photos**.
5. Open a shared photo and briefly show photographer/capture time, **Report**,
   and **Block contributor**. Do not submit a report in the final hosted event.
6. Open **Make recap**. Select/reorder photos, choose a template and music,
   preview, then show save/share.
7. Cut to the Debug showcase `paywallPopulated` fixture, keeping the synthetic
   data label visible. Show localized product choices, renewal terms, **Restore
   Purchases**, and **Manage Subscriptions**. Replace this shot with the Release
   paywall after the production App Store catalog is attached.
8. Finish on **You**, showing **Delete account** and its confirmation alert.

## Stable Debug fixtures

Set `MOSAIC_SHOWCASE_SCREEN` in the Debug scheme environment and relaunch for
the deterministic scenes used by UI automation:

- `active`
- `revealed`
- `photos`
- `recapJourney`
- `cameraReview`
- `paywallPopulated`
- `you`

These fixtures are compiled only in Debug. The App Store Release binary uses
the hosted Supabase backend and does not contain a showcase route.

## Before recording

- Open **Camera** once on the physical iPhone and confirm all locally queued
  photos finish uploading before recording another shot.
- Attach the production App Store products to RevenueCat and confirm the Release
  paywall displays localized StoreKit prices. Until then, the Debug paywall is
  suitable only as a clearly labeled UI demonstration, not purchase validation.
- Keep `REVIEW26` for the hosted join/activity portion and avoid showing any
  personal event, photo, Apple ID, or notification content.

## Suggested narration

“Mosaic turns invitation-only acts of kindness into one shared artwork. Every
self-attested activity places one equal-size tile—there are no scores, proof,
or organizer approvals. A separate disposable camera keeps photos sealed until
the fixed reveal. After reveal, members can browse the artwork, kindness, and
photos, report or block unsafe content, and create a private photo-only recap.
Participants are always free; optional organizer purchases only expand event
creation limits. Sign in with Apple and in-app account deletion are built in.”

## Upload after App Store Connect authentication

After the version and review-detail IDs are known:

```sh
asc review attachments-upload \
  --review-detail REVIEW_DETAIL_ID \
  --file submission/Mosaic-App-Review-1.0.mp4
```

Keep the upload under `submission/` and confirm the attachment appears with
`asc review attachments-list --review-detail REVIEW_DETAIL_ID`.
