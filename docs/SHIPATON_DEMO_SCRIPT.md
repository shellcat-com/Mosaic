# Mosaic Shipaton demo — 1 minute 50 seconds

**Hard limit:** keep the uploaded YouTube or Vimeo video below 2:00.

**Target:** 1:45–1:55, English narration and captions, no unlicensed music.

## Capture checklist

- Use the `Mosaic Shipaton` scheme on an iPhone Simulator or device.
- Supply the RevenueCat Test Store public SDK key through `Config/Local.xcconfig`.
- Sign in with Apple and create a recoverable organizer workspace before recording the purchase.
- Clear or reset Test Store purchase state so the Free → Organizer Plus transition is visible.
- Record raw app footage. Do not use generated product UI in place of the running app.

## Timeline

| Time | Picture | Narration |
| --- | --- | --- |
| 0:00–0:12 | Home mosaic growing from equal-size tiles | “Small acts of kindness often disappear. Mosaic gives each verified act one equal place in a story a community reveals together.” |
| 0:12–0:32 | Invitation, mission, private evidence, consent | “An invited participant chooses an approachable mission. Evidence is private to organizers, while identity, memory inclusion, and recap consent remain separate choices.” |
| 0:32–0:48 | Tile creation and placement | “Emotion, mission, and verification shape a ceramic tile. Every tile is the same size—there are no rankings, likes, or paid visual advantages.” |
| 0:48–1:02 | Organizer moderation and final reveal | “Organizers verify outcomes without exposing proof. At the scheduled reveal, approved memories and an attributable Impact Receipt open with the shared artwork.” |
| 1:02–1:30 | Free plan, RevenueCat Paywall V2, Test Store purchase, success modal | “Participants contribute for free. Organizers fund larger community events through Organizer Plus. This is a real RevenueCat Test Store purchase, attached to the organizer’s Supabase identity.” |
| 1:30–1:40 | Organizer Plus active, 25 → 250 people, premium controls enabled | “RevenueCat returns the entitlement, Mosaic synchronizes it server-side, and organizer capacity and creation tools unlock immediately.” |
| 1:40–1:50 | Architecture/privacy card and repository hero | “SwiftUI, RevenueCat, and a Supabase backend keep billing authoritative and community evidence private. Mosaic: small acts, one shared story.” |

## Required proof frames

1. RevenueCat offering and prices load.
2. The Test Store purchase success control is tapped on camera.
3. The paywall closes and `Organizer Plus` appears.
4. The participant limit changes from 25 to 250 or a gated organizer capability becomes enabled.
5. The final frame shows `github.com/shellcat-com/Mosaic`.

## Export acceptance

- H.264 video with AAC narration, 1080p or higher.
- Duration reported by `ffprobe` is less than 120 seconds.
- Captions are reviewed for names, technical terms, and timing.
- Public visibility is confirmed in a signed-out browser before adding the URL to Devpost.
- `./scripts/validate_shipaton_submission.sh --require-video` passes before upload.
