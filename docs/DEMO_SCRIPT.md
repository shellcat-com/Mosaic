# Three-minute demo script

## 0:00–0:25 — The problem

Kind acts usually disappear into private moments. Mosaic gives a group a shared goal without turning kindness into a leaderboard: every verified contribution becomes one equal-size ceramic tile.

## 0:25–0:50 — Instant private guest

Launch on Simulator A. Complete onboarding, choose a guest name, and select a private identity mode. Point out that anonymous Supabase Auth provides a durable identity without a sign-up form and that the public showcase cannot be edited.

## 0:50–1:25 — Evidence and consent

Open the organizer sandbox and choose a mission. Submit one evidence path—reflection is fastest, while the picker demonstrates photo, short video, receipt, and organizer confirmation. On Privacy Review, vary memory inclusion, identity display, and export consent to show that these choices are independent.

## 1:25–1:55 — Moderation

Open the organizer dashboard. Approve evidence and decide on the memory separately. Mention that evidence is private, Realtime never carries it, and the mosaic table stores only abstract mission/emotion/method state.

## 1:55–2:20 — Live collaboration

Copy the sandbox invite code. On Simulator B, join that code as another anonymous guest. Place the approved tile on Simulator A and show Simulator B refreshing from the private `challenge:<uuid>` notification.

## 2:20–2:42 — Synchronized reveal

Trigger Reveal Now from the organizer dashboard. Show both devices entering the revealed state, then open the Impact Receipt. Emphasize equal tile weight, collective progress, and consent-aware memories.

## 2:42–3:00 — Why it scales

Close on the architecture: anonymous Auth, RLS on every exposed table, private Storage signed URLs, narrow Edge Function transitions, atomic placement, cron-based scheduled reveals, and canonical refetch after sanitized Realtime invalidations. Note VoiceOver labels, Dynamic Type, and Reduce Motion/Transparency support.

## Recording checklist

- Use synthetic names and media only.
- Prewarm both Simulators and verify the hosted project before recording.
- Keep the invite code visible long enough to follow.
- Capture one recoverable-error or cached-state screen as backup B-roll.
- End with repository URL, license, setup instructions, and the deferred-scope statement.
