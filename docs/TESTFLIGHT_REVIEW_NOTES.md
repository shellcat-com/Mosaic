# TestFlight and App Review notes — Mosaic v1

Mosaic gives invitation-only communities a shared kindness activity, collaborative artwork reveal, and separate disposable-photo gallery. Participants are always free. Organizers can use the free creation tier or buy Mosaic Plus/Event Pass access through Apple's in-app purchase flow. Mosaic has no anonymous participation, proof/evidence capture, organizer approval queue, or configurable privacy mode.

## Account

Use the native **Sign in with Apple** button and create a 2–40 character display name. No developer-issued username or password exists. Account deletion is in **You → Delete account**.

Use this stable, synthetic hosted invitation:

- Active Mosaic: `REVIEW26` — remains joinable through December 31, 2027.

Joining closes at the fixed reveal time, so a revealed event cannot safely use a
public invitation for a new reviewer account. The attached review video shows the
complete revealed artwork, Kindness, Photos, reporting/blocking, and recap paths.

Open an invitation with `mosaic://join/CODE` or enter its code under **Mosaics → Join**.

## Paths to review

1. In the active Mosaic, open an Activity, tap **I took part**, and optionally add a note. This self-attested action adds one equal-size tile; it does not request evidence or approval.
2. Open **Camera**, choose the active Mosaic, allow Camera, take a still photo, and keep or retake it. The camera does not record video or import from Photos.
3. The attached review video shows a revealed Mosaic and switches among **Artwork**, **Kindness**, and **Photos**. These destinations are deliberately separate.
4. The video also opens a shared photo to show photographer/capture time, reporting, contributor blocking, and immediate quarantine.
5. The video demonstrates **Make recap** with photo selection, reordering, templates, music, preview, and save/share. Recaps contain captured photos only—no artwork, notes, activities, names, captions, title cards, or statistics.
6. During creation, choose a premium board size, shot limit, or film look to open **Make room for more people**. The monthly, annual, and Event Pass choices use live localized Store data after the production App Store catalog is attached. **Restore Purchases** is available on the same screen. Premium access changes organizer creation limits only; it never restricts participants.

The reveal is fixed and server-timed; there is no early organizer reveal. Camera testing requires physical camera hardware. Mosaic uses on-device Sensitive Content Analysis and CryptoKit AES-GCM for the scheduled artwork package.

Support: https://shellcat-com.github.io/Mosaic/support/

Privacy: https://shellcat-com.github.io/Mosaic/privacy/

Community Guidelines: https://shellcat-com.github.io/Mosaic/community-guidelines/

Reviewer contact: biswas06@iastate.edu
