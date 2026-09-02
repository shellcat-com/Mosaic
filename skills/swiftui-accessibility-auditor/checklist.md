# Mosaic v3 SwiftUI accessibility audit

Audited: 2026-08-26  
Scope: the focused `MosaicV3` iPhone target at an iOS 18 deployment target.

## P0

No blocker-level accessibility defects remain in the reviewed source.

## P1 fixes applied

- **Extreme Dynamic Type could compress adjacent controls and facts.** Side-by-side Create/Join controls, event facts, invite details, gallery actions, creation controls, and summary cards could wrap into narrow columns. These layouts now switch to vertical arrangements when `DynamicTypeSize.isAccessibilitySize` is true.
- **The static board exposed every noninteractive tile to VoiceOver.** A 25- or 100-tile board would require dozens of swipes without offering an action. The active board is now one summarized accessibility element; the revealed Kindness board exposes contributed, tappable tiles and hides empty porcelain positions.
- **The kindness-to-art explanation could overflow at accessibility sizes.** `TileSideStory` now uses a dedicated vertical presentation with the complete explanation at accessibility categories.
- **Page titles lacked heading semantics.** `MosaicTitle` now keeps its children in reading order and marks the title as a header instead of combining the eyebrow, title, and detail into one undifferentiated announcement.
- **Photo gallery context lacked heading semantics.** “Disposable gallery” is now exposed as a header.
- **Completion, camera, gallery, and recap results were visual-only status changes.** Their existing messages now post concise VoiceOver announcements when they change; the visible text remains the source of truth.
- **Camera shot-limit and recap-template choices became cramped at accessibility sizes.** Both choice groups now become full-width vertical controls while preserving the same values and selection state.
- **Event names lacked heading semantics.** The primary event title is now exposed as a header without combining its description or live facts into the same element.
- **Transient ceremonies exposed controls behind their overlays.** The activity/event content is now hidden from assistive technologies while tile placement is presented, and the camera body is hidden while on-device development is in progress. The development status receives modal accessibility focus.
- **The recap stage segmented control could truncate at Accessibility text sizes.** It now becomes a full-width menu at accessibility categories while retaining the four exact stages and the compact segmented presentation at standard sizes.
- **The camera event picker had a redundant spoken chevron.** Its decorative disclosure glyph is now hidden while the actual Picker remains the sole interactive element.
- **Dense 64/81/100-tile Kindness boards could not provide reliable 44-point tile targets.** The ceramic grid remains visually intact, but dense boards now expose one summarized board element plus a disclosure-based contribution browser with full-width 44-point rows. Small boards retain direct tile activation.
- **Icon-only activity and recap reorder controls inherited undersized intrinsic hit areas.** Every Move Up, Move Down, Move Earlier, Move Later, and Delete control now reserves its own 44×44-point minimum target while keeping the compact icon presentation.
- **Disabled primary and secondary actions looked enabled.** Shared button styles now read `isEnabled`, remove elevation, and use a muted clay treatment when unavailable; enabled controls retain the tactile glaze treatment. State is no longer communicated only through failed activation.

## P2 observations

- Selection never relies on color alone: film looks and recap templates include checkmarks or borders, photo selection includes an order number, completed activities include a checkmark seal, and the completed outcome uses labeled segments.
- Custom image, tile, template, gallery, and shutter interactions are `Button` controls rather than touch-only gestures.
- Icon-only reorder controls retain their visible string labels for VoiceOver and Voice Control even when `.labelStyle(.iconOnly)` hides the text visually.
- All custom action targets meet or exceed 44 points. Developed-roll delete and icon-only reorder controls explicitly reserve 44-point targets; dense boards provide a separate full-width contribution browser because a 10×10 visual grid cannot physically provide 44-point tiles on iPhone.
- Tile placement and artwork reveal honor Reduce Motion; their reduced-motion paths settle immediately or crossfade without 3D sequencing.

## Manual verification checklist

- Turn on VoiceOver. Confirm the home screen reads eyebrow, header, supporting text, Create, Join, section headers, then each Mosaic card in visual order.
- Open an active Mosaic. Confirm the board is announced once with its contributed count; it must not announce every static tile.
- Open the revealed Kindness side. Confirm only contributed tiles are focusable and each announces the contributor before activation.
- Open a 100-tile revealed Kindness side. Confirm the visual grid is announced once, “Browse kindness contributions” expands, each row announces contributor and tile number, and Voice Control or Switch Control can activate a row without targeting a tiny ceramic tile.
- Complete an activity. Confirm the result is announced once, focus remains inside the placement ceremony, Skip and Continue are reachable, and Continue returns to the event rather than exposing content behind the modal.
- Capture a photo with VoiceOver enabled. Confirm focus moves to the developing status, no camera controls remain reachable while processing, and the review controls become reachable afterward.
- Use Voice Control commands “Tap Create,” “Tap Join,” “Tap Choose an act,” “Tap Open disposable camera,” “Tap Keep photo,” “Tap Retake,” and “Tap Render recap.” Each visible name should activate the matching control.
- Enable Switch Control and scan the creation flow (including activity reorder and shot limits), camera shutter/review, photo grid, recap template cards, music rows, and export controls. No action should require a gesture-only interaction.
- Set text size to Accessibility XXXL. Confirm actions stack vertically, text remains untruncated, cards grow vertically, and every screen remains scrollable. Simulator evidence: `design/ui-review-v3-polished/accessibility-home.png`.
- At Accessibility XXXL, open Recap and confirm the stage selector is a labeled menu containing Photos, Order, Style, and Preview rather than a truncated segmented control.
- Enable Reduce Motion, contribute to an activity, and open a newly revealed event. Confirm placement settles without rotation and reveal uses a short crossfade. Switching Artwork/Kindness/Photos must not restart reveal; Skip and Replay remain reachable.
- Enable Increase Contrast and Differentiate Without Color. Confirm selected templates, selected photos, activity completion, and outcome selection retain non-color indicators.
- Open an empty creation form. Confirm Continue is visibly muted, announced as dimmed, and cannot be activated; enter the required fields and confirm its tactile glaze/elevation returns.
- With camera permission denied, confirm VoiceOver reaches the explanation and “Open Settings” button in order.

## Automated verification

- XCTest's system accessibility audit passes across Home, Create, active and revealed Mosaics, Camera, and Recap for hit regions, descriptions, traits, clipping, and the remaining supported checks.
- Dedicated Accessibility XXXL UI journeys verify the active-event story/action hierarchy, adaptive Recap stage menu, and simplified disposable-camera summary.
- Dense 100-tile Kindness UI automation verifies that the contribution browser exposes full-size, hittable rows.
- Deterministic unit tests enforce primary, accent, and secondary foreground contrast against their intended light and dark materials. These replace XCTest's pixel-level contrast audit for the custom display font, which produces false positives despite opaque WCAG-compliant palette pairs.

## Expected outcomes and regression risk

Expected behavior is unchanged except for improved semantics, concise status announcements, fewer redundant board announcements, and vertical layouts at accessibility text sizes. The main regression risks are additional vertical scrolling at accessibility sizes and repeated announcements if one status string is assigned more than once; the former is intentional, while the latter should be checked whenever asynchronous camera or export messaging changes. Recheck compact default-size screenshots after any future typography or card-layout change.
