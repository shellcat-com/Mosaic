# TestFlight and App Review notes — Mosaic v1

Mosaic gives invitation-only communities a shared kindness activity, collaborative artwork reveal, and separate disposable-photo gallery. Participants are always free. Organizers can use the free creation tier or buy Mosaic Plus/Event Pass access through Apple's in-app purchase flow. Mosaic has no anonymous participation, proof/evidence capture, organizer approval queue, or configurable privacy mode.

## Account

Use the native **Sign in with Apple** button and create a 2–40 character display name. No developer-issued username or password exists. Account deletion is in **You → Delete account**.

Before submission, replace these placeholders with live hosted invitations:

- Active Mosaic: `[ACTIVE INVITATION CODE]` — reveals during the review window.
- Revealed Mosaic: `[REVEALED INVITATION CODE]` — contains synthetic, review-safe contributions and photos.

Open an invitation with `mosaic://join/CODE` or enter its code under **Mosaics → Join**.

## Paths to review

1. In the active Mosaic, open an Activity, tap **I took part**, and optionally add a note. This self-attested action adds one equal-size tile; it does not request evidence or approval.
2. Open **Camera**, choose the active Mosaic, allow Camera, take a still photo, and keep or retake it. The camera does not record video or import from Photos.
3. Open the revealed Mosaic and switch among **Artwork**, **Kindness**, and **Photos**. These destinations are deliberately separate.
4. In **Photos**, open a shared photo to see photographer and capture time, Report it, or Block its contributor. A report immediately quarantines the photo.
5. Tap **Make recap**, choose 1–24 photos, reorder them, select a template and music, preview, then save/share. Recaps contain captured photos only—no artwork, notes, activities, names, captions, title cards, or statistics.
6. During creation, choose a premium board size, shot limit, or film look to open **Make room for more people**. The monthly, annual, and Event Pass choices use live localized Store data. **Restore Purchases** is available on the same screen. Premium access changes organizer creation limits only; it never restricts participants.

The reveal is fixed and server-timed; there is no early organizer reveal. Camera testing requires physical camera hardware. Mosaic uses on-device Sensitive Content Analysis and CryptoKit AES-GCM for the scheduled artwork package.

Support: https://shellcat-com.github.io/Mosaic/support/

Privacy: https://shellcat-com.github.io/Mosaic/privacy/

Community Guidelines: https://shellcat-com.github.io/Mosaic/community-guidelines/

Reviewer contact: biswas06@iastate.edu
