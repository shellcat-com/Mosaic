# Reverie Hacks demo script — 3:00 target

## 0:00–0:20 — The disappearing-kindness problem

Kind acts usually disappear into private moments. Mosaic gives a group a shared goal without turning kindness into a leaderboard: every verified contribution becomes one equal-size ceramic tile.

## 0:20–0:45 — Join instantly and privately

Open the seeded showcase, choose a guest name and privacy mode, and join through Supabase anonymous authentication. Point out that there is no account wall and that the synthetic showcase cannot be vandalized.

## 0:45–1:15 — Submit evidence with consent

Open a mission and show reflection, photo, video, receipt, and organizer-approval choices. Submit the prepared reflection, then show the independent toggles for memory inclusion, identity display, and export consent. Mention the 10-second video validation and private Storage signed URLs.

## 1:15–1:45 — Moderate in an isolated sandbox

Switch to the organizer sandbox and open a pending synthetic submission. Approve the evidence, review the memory separately, and place the tile. Explain that evidence, identity, and memories live behind separate RLS policies and that every lifecycle transition is authorized server-side.

## 1:45–2:10 — Show live collaboration

Join the sandbox invite code from a second iPhone Simulator. Place another prepared tile on one device and show the other device refresh through a private `challenge:<uuid>` Realtime invalidation. Emphasize that no evidence or owner record is broadcast.

## 2:10–2:35 — Reveal and Impact Receipt

Trigger the synchronized reveal. Show the completed mosaic, consent-aware memories, and Impact Receipt/recap. Briefly mention that scheduled reveals are also activated by the minute-level database cron.

## 2:35–3:00 — Architecture and close

Flash the repository's Supabase migrations, pgTAP policies, Edge Functions, and passing iPhone 17 Pro tests. Close with Mosaic's equal-weight design, anonymous participation, private evidence, accessibility support, cached read-only recovery, and a backend that scales by challenge membership instead of trusting the client.

## Recording checklist

- Use synthetic names and media only.
- Record the primary journey on an iPhone Simulator; use two Simulators for Realtime.
- Prewarm the hosted Supabase project and organizer sandbox before recording.
- Keep text large enough to read in the final Devpost player.
- Show VoiceOver labels, Dynamic Type, or Reduce Motion behavior in one short accessibility beat.
- Keep invitation tokens synthetic and avoid showing dashboard identifiers.
- Capture one cached or recoverable-error screen as optional B-roll.
- Keep the final edit at or below three minutes, including title and end cards.
