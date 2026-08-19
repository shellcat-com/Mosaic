# Mosaic — Complete Product and iOS Design Blueprint

## Summary

Mosaic is a collaborative kindness app that turns real-world acts of care into a shared living artwork and an emotional community memory. A school, neighborhood, workplace, nonprofit, or friend group creates a time-limited challenge, chooses a goal and hidden visual theme, defines how contributions can be verified, and invites people through a link, QR code, or short challenge code.

Participants choose approachable missions such as leaving an encouraging note, donating an item, cleaning a shared space, teaching a useful skill, supporting a local organization, or checking in on someone who may feel isolated. After completing the action, they submit an accepted form of private evidence: a reflection, photo, short video, receipt, partner confirmation, or organizer approval. Evidence is kept separate from storytelling. Each participant independently controls whether their name, reflection, or approved media can appear in the final community memory.

Every verified action creates an equal-size digital ceramic tile. Its glaze color represents the emotion behind the act, its embossed pattern represents the mission category, and its surface texture represents the verification method. Participants place their tiles into the growing mosaic and can use **Pass the Tile** to invite someone else to continue the chain. Invitations that are accepted after becoming dormant create glowing gold kintsugi connections, transforming a pause into a visible symbol of renewal.

During the challenge, participants see collective momentum without rankings or points. The mosaic grows through ceramic forms, blurred color, silhouettes, light, and movement while the final artwork and sealed stories remain hidden. When the community reaches its goal or the scheduled reveal begins, Mosaic presents a synchronized cinematic ceremony: tiles illuminate, kindness chains ripple across the artwork, kintsugi seams glow, approved memories unfold, and the complete mosaic is revealed with an Impact Receipt.

Mosaic then creates a privacy-safe vertical recap from the artwork's growth, approved memories, verified outcomes, and final reveal. Communities can share the recap, save the completed artwork, print it as a poster, display it at an event, or carry its visual theme into their next challenge.

Mosaic does not turn kindness into a competition. It gives every action an equal place in a collective story. The waiting creates anticipation, the tiles create belonging, the memories preserve emotion, and the Impact Receipt demonstrates how many small contributions can become something meaningful, measurable, and larger than any one person.

## Product Thesis

> Small acts often disappear after they happen. Mosaic makes them visible without making them competitive.

The product combines four systems:

1. **Kindness challenge:** gives a community a shared purpose, deadline, and attainable set of actions.
2. **Private verification:** creates trust without forcing evidence into a public social feed.
3. **Living mosaic:** gives every verified contribution equal visual permanence.
4. **Reveal and memory:** converts collective activity into an emotional artifact worth keeping and sharing.

## How Mosaic Works

### 1. Create

An organizer defines:

- Challenge name and purpose.
- Community goal and duration.
- Scheduled reveal time.
- Mission library and custom missions.
- Accepted evidence for each mission.
- Curated artwork or Organizer Plus custom artwork.
- Participant and story-visibility rules.

### 2. Invite

Mosaic creates:

- Universal invitation link.
- Scannable QR code.
- Short challenge code.
- Printable and shareable invitation artwork.

All v1 challenges are unlisted and invitation-only.

### 3. Join

Participants can join guest-first with a display name, anonymously, or quietly. Sign in with Apple is required only for hosting, purchasing, cross-device history, and contribution recovery.

### 4. Act

Participants choose a mission based on category, effort, time, accessibility, and accepted verification methods, then complete the action in the real world.

### 5. Verify privately

The participant submits one method accepted by the mission:

- Reflection.
- Photo.
- Video up to 10 seconds.
- Receipt with crop and redaction.
- Private partner confirmation.
- Organizer approval.

Evidence is never automatically published as a memory.

### 6. Create and place the tile

After verification, the contribution becomes a ceramic tile:

- Emotion determines glaze color.
- Mission category determines embossed pattern.
- Verification method determines surface texture.
- The contribution identifier creates a unique edge profile and maker's mark.

The participant places the tile into an equal-size open position in the community mosaic.

### 7. Pass the Tile

The participant shares a private continuation link. A normal acceptance creates a subtle connection; a late acceptance repairs the dormant link with kintsugi gold. Chain length is visible as collective momentum but never ranked.

### 8. Develop the Mosaic

The live artwork shows only abstract ceramic information. The final image and participant stories remain sealed. At the goal or scheduled reveal time, the cinematic ceremony develops the complete artwork and opens only approved, consented memories.

### 9. Prove and preserve impact

The Impact Receipt distinguishes verified, confirmed, and self-attested outcomes. Mosaic generates a vertical recap, high-resolution artwork, and printable poster using only content with explicit export consent.

## Core Roles

### Participant

- Joins a challenge.
- Completes and privately verifies missions.
- Controls identity and story consent.
- Creates, places, and passes a tile.
- Attends and explores the reveal.

### Organizer

- Creates and configures challenges.
- Selects missions and evidence policies.
- Reviews pending evidence and shared memories.
- Manages invitations, reports, and reveal timing.
- Approves the recap and exports.

### Confirmation partner

- Opens a single-purpose confirmation link.
- Confirms or declines that the action occurred.
- Does not need an account or receive access to the challenge.

## Contribution Lifecycle

`draft → evidence submitted → pending/self-attested → verified → tile created → tile placed → story approved → revealed → archived`

- A pending contribution reserves an unfired clay position visible only as a neutral placeholder.
- Verification fires and permanently styles the tile.
- Story approval is independent from evidence verification.
- Removing a contribution removes its impact totals and returns its position to the mosaic without exposing the reason publicly.

## Design North Star — Living Kiln

Mosaic should feel like a warm community ceramic studio brought to life on iOS:

- Porcelain content surfaces and tactile glazed tiles.
- Native, restrained controls that stay secondary to the artwork.
- Kintsugi gold reserved exclusively for revived chains.
- Emotional editorial typography paired with highly legible system typography.
- Motion that explains status: shaping, firing, placing, connecting, developing, and revealing.
- Full support for VoiceOver, Dynamic Type, Reduce Motion, Reduce Transparency, and non-color state communication.

The visual system is documented in [`design/DESIGN_DIRECTION.md`](design/DESIGN_DIRECTION.md).

## V1 Product Boundary

Included:

- iPhone-first app.
- Invitation-only challenges.
- Guest participation and Sign in with Apple.
- Six verification methods.
- Organizer moderation.
- Ceramic tile generation and placement.
- Pass the Tile chains and kintsugi revival.
- Synchronized reveal, memories, Impact Receipt, recap, and poster export.
- Organizer Plus through RevenueCat.

Excluded:

- Public challenge discovery.
- Direct messages, comments, likes, followers, and leaderboards.
- Location tracking or public participant maps.
- Unmoderated public user content.
- Participant purchases that visually distinguish contributions.
