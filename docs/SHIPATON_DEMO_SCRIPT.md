# Mosaic Next Gen demo — target 1:45

The uploaded public YouTube or Vimeo video must stay below two minutes. Use English captions and licensed/original audio only.

## Recording setup

- Build the normal `Mosaic` scheme in Debug with an ignored RevenueCat Test Store public key from `Config/Debug.xcconfig`.
- Use a signed-in organizer whose RevenueCat `appUserID` visibly matches the lowercase Supabase UUID in debug logs.
- Start free with no active Mosaic and reset the chosen Test Store product so the purchase transition is genuine.
- Record the running V3 app without a device frame or generated replacement UI.

## Timeline

| Time | Picture | Narration |
| --- | --- | --- |
| 0:00–0:12 | V3 home and equal ceramic tiles | “Mosaic turns small acts of kindness into one artwork a group reveals together—without rankings, likes, or larger tiles for paying users.” |
| 0:12–0:30 | Create a free 25-tile Mosaic with Sunwashed and 12 shots | “Participants are always free. Every contribution receives equal weight, while a free organizer can run one unrevealed Mosaic.” |
| 0:30–0:48 | Invitation, join, kindness activity, disposable photo roll | “Members join privately, choose an act, and share a sealed disposable roll. Attribution and reveal access never depend on payment.” |
| 0:48–1:03 | Tap a locked 100-tile goal; Living Kiln paywall opens | “Organizer Plus makes room for larger groups: up to 100 tiles, 36 shots per member, every film look, and multiple active Mosaics.” |
| 1:03–1:21 | Live annual/monthly/Event Pass cards and genuine Test Store purchase | “These localized options come from RevenueCat. Annual and monthly unlock Plus; a one-event pass grants one server-tracked PASS.” |
| 1:21–1:34 | ‘Confirming access’ then server-confirmed Plus card | “The client never authorizes itself. Supabase reconciles RevenueCat API v2 before premium controls unlock.” |
| 1:34–1:46 | Return to creation and select 100 tiles/all looks | “The new Mosaic captures premium access permanently, so a future expiry can block new premium events without damaging this one.” |
| 1:46–1:50 | Public repository and Mosaic mark | “Mosaic is student-built, open source, and ready for Next Gen.” |

## Proof frames

1. Custom “Make room for more people” paywall with three live packages.
2. Genuine RevenueCat Test Store confirmation.
3. Server synchronization progress followed by confirmed Plus state.
4. Visible 100-tile option unlocked after reconciliation.
5. Public `github.com/shellcat-com/Mosaic` repository and MIT license.

## Export acceptance

- 100–110 seconds preferred; always less than 120 seconds.
- 1920×1080 H.264 with AAC narration, or higher.
- Captions reviewed for Mosaic, RevenueCat, Organizer Plus, Supabase, and PASS.
- Public/unlisted playback verified while signed out.
- `./scripts/validate_shipaton_submission.sh --require-video` passes before upload.
