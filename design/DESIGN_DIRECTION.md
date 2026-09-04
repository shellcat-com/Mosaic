# Mosaic Design Direction — Living Kiln

## North star

Mosaic should feel like a warm community ceramic studio brought to life on iOS. The shared artwork is always the hero. Controls remain calm, native, and secondary to the tactile tiles, sealed stories, and collective reveal.

## What we take from the references

- Object-first presentation: one memorable artifact dominates each screen.
- Handmade warmth paired with disciplined interface hierarchy.
- Personalization that produces something worth saving and sharing.
- Anticipation, hidden content, and a ceremonial final state.
- Physical metaphors that explain digital behavior without tutorials.

We do not copy Bubbbly's flowers, glass-card layouts, butterfly imagery, typography, branding, or background compositions.

## Visual system — Playful Living Kiln

| Role | Token | Value |
| --- | --- | --- |
| Light canvas | Porcelain | `#FBF8F1` |
| Light surface | Paper | `#FFFDF8` |
| Light text | Ink | `#25221F` |
| Kiln-night canvas | Charcoal | `#141210` |
| Kiln-night surface | Fired paper | `#201D19` |
| Kiln-night text | Warm ivory | `#F7F1E7` |
| Primary interaction | Kiln Indigo | `#5A47F2` |
| Warm action accent | Persimmon | `#F56E3E` |
| Tile glaze | Sage | `#7D9A83` |
| Tile glaze | Sky | `#7EB7CD` |
| Tile glaze | Rose | `#E4A6B4` |
| Revived chains only | Kintsugi Gold | `#D6A937` |

- Use bundled Fraunces 72pt Soft for emotional display headings and large numbers. Use Dynamic Type-scaled SF Pro Rounded for controls, data, forms, and body copy.
- Use fine speckle, custom doodle symbols, irregular ceramic edges, organic paper swatches, and restrained directional shadows.
- Reserve translucent material for navigation and temporary controls. Content surfaces remain porcelain, clay, paper, or ceramic.
- Keep every contribution tile the same size and visual weight.
- Follow the system appearance automatically. The dark appearance is a warm kiln-night environment, not a neutral black inversion.

## Original asset inventory

- Fifteen code-native vector doodles: Home, Mosaics, You, encouragement, community, giving, connection, teaching, support, spark, chain, kintsugi, kiln, tile, and memory.
- Six code-native color stickers: sparkles, kind note, helping hands, neighborhood sprout, gift ribbon, and ceramic sun.
- System actions remain SF Symbols so close, back, share, camera, lock, accessibility, and disclosure controls keep familiar iOS meaning.
- Fraunces is bundled under the SIL Open Font License; the license file ships beside the three font weights.

## Decoration rules

- Give each screen one dominant artifact or illustration and at most one small supporting sticker above the fold.
- Use organic pastel panels for emphasis, empty states, and ceremony—not around every row or paragraph.
- Doodles may communicate navigation, category, or emotional tone; they must never replace a familiar safety or system-action symbol.
- Preserve generous negative space, but keep challenge progress, privacy state, and the primary action immediately visible.
- Avoid copied reference artwork, random rotations that hurt alignment, low-contrast pastel text, or decoration behind long-form copy.

## Screen composition

1. **Home:** challenge identity, collective progress, living mosaic preview, and one clear mission action.
2. **Mission:** one ceramic mission object, short meaningful copy, accepted evidence, and one completion action.
3. **Tile ceremony:** the participant's tile floats above the shared mosaic and follows their drag gesture into an available position.
4. **Reveal:** the environment darkens, the mosaic becomes luminous, kintsugi seams ripple through revived chains, and the Impact Receipt appears after the artwork.

## Tile grammar

- Color represents emotion.
- Embossed pattern represents mission category.
- Surface texture represents verification method.
- A maker's mark distinguishes the contributor without changing prominence.
- Gold appears only where a dormant Pass the Tile chain was revived.

## Interaction and motion

- Tap feedback: 160–220 ms.
- Tile placement: 450–650 ms, directly following the finger.
- Tile firing: approximately 1.8 seconds.
- Kintsugi repair: approximately 1.2 seconds.
- Full reveal: 6–8 seconds, skippable and replayable.
- Reduce Motion replaces travel, depth, blur, and parallax with crossfades.

## Corrections before production screens

- Use three root destinations rather than the five-tab exploration shown in the concept board: Groups, Camera, and You.
- Keep Persimmon as a warm accent; Kiln Indigo should remain the main interactive color for accessible consistency.
- Impact Receipt values must be attributable. Never use vague claims such as “countless.” Separate verified and self-attested outcomes.
- Display explicit countdown and reveal timing on active challenges.
- Show evidence method, privacy mode, and story consent before creating the tile.
- Preserve equal tile sizes when adding chain and kintsugi states.
- Treat the board as art direction, not pixel-final interface or final product copy.

## Next design set

The next high-fidelity set should cover the complete participant loop: invitation preview, guest join, mission selection, evidence capture, privacy controls, tile firing, placement, Pass the Tile, countdown lobby, reveal, memories, and Impact Receipt.

## Evidence camera

- Keep the preview edge-to-edge so photographing the completed action remains the primary task.
- Show the active mission in a compact porcelain pill at the top rather than repeating a large title.
- Keep an always-visible “Evidence stays private” shield below the mission.
- Place flash, close, crop, library, and camera-flip controls where people already expect them on iOS.
- Use a porcelain bottom shelf for the `PHOTO`, `VIDEO`, and `RECEIPT` modes. The selected state uses Kiln Indigo.
- Use a large ceramic shutter with an indigo inner ring; video replaces the ring with a persimmon record state and a 10-second timer.
- Provide in-context safety guidance: avoid faces, addresses, school identifiers, payment details, and other private information.
- After capture, show only `Retake` and `Use Photo` as primary decisions. Cropping remains available as a secondary control.
- Separate evidence visibility from community-story consent. Evidence defaults to organizer-only and cannot be made public from the camera.
- `Include this memory` is off by default and may be enabled only after the participant sees what will be shared.
- Receipt mode adds perspective correction and redaction before the normal review screen.
- Denied permissions must offer `Choose from Library` and clear Settings guidance without blocking reflections or other accepted evidence methods.
