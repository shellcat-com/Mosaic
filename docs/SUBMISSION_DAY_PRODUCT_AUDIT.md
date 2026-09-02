# Mosaic Submission-Day Product, UI/UX, and Hackathon Audit

**Audit date:** August 31, 2026  
**Scope:** Shipping `MosaicV3` app, repository documentation, screenshots, release checks, Supabase/RevenueCat integration evidence, and Shipaton requirements.  
**Method:** Direct source and artifact review, expert heuristic walkthrough, accessibility review, two proxy usability surveys, public-repository comparison, local validation scripts, a successful clean Simulator baseline with 46 Swift tests and 15 UI journeys, and a final submission-day build after the fixes below. This is not a substitute for observed user research.

## Executive verdict

Mosaic is strong enough to submit to the **Shipaton Next Gen category today** once the public repository, genuine final video, eligibility, and Devpost entry are made truthful and complete. The product idea is distinctive, coherent, and more mature than the public GitHub page suggests. Current V3 screenshot and paywall assets now exist; the main remaining risk is that judges may still see an old public-repository story or placeholder video instead of the app that now exists.

Mosaic is **not yet evidenced as App Store-ready today**. Production IAP configuration, App Store Connect metadata/compliance, distribution signing/upload status, and reviewer information remain unresolved. Submitting a Next Gen hackathon entry and submitting a production App Store binary are therefore two different readiness decisions.

### Submission-day scorecard

| Area | Score | Verdict |
|---|---:|---|
| Product thesis and originality | 9.0/10 | A memorable idea with an unusually humane incentive model |
| Visual identity | 8.2/10 | Cohesive, warm, and recognizable; a few screens are more form-like than magical |
| Information architecture | 8.4/10 | Three-tab structure is clear and appropriately small |
| Core-flow usability | 8.7/10 | Strong join/kindness/reveal flow; creation and recap now protect in-session work and explain outcomes earlier |
| Accessibility foundations | 8.6/10 | Dynamic Type, labels, reduced motion, and dense-board alternatives are thoughtfully handled |
| Delight and emotional payoff | 8.5/10 | Camera, tile placement, and reveal are the product's signature moments |
| Technical/product care | 9.0/10 | Strong domain boundaries and server authority; privacy, retry, rendering cancellation, gallery loading, and camera-threading gaps are addressed |
| Hackathon materials readiness | 7.8/10 | Current screenshot/paywall/captions and verified build exist; genuine video, public publishing, eligibility, and Devpost remain blocking |
| App Store readiness | 4.5/10 | Release validation passes, but commercial/distribution evidence is incomplete |

## What is working—and worth protecting

1. **Equal-size kindness tiles are the right product decision.** There is no leaderboard, score, proof hierarchy, or public ranking. A small act receives the same visual weight as any other act. That is the clearest expression of the original idea.
2. **The two-sided tile is an excellent metaphor.** One side carries the personal contribution; the other participates in the shared artwork. Individual action and collective outcome are connected without turning kindness into content performance.
3. **The reveal creates a real ritual.** A fixed reveal time, placement ceremony, countdown, completed board, and replayable unveiling create anticipation and a finish line. This is much more memorable than a conventional social feed.
4. **The disposable camera is separate from proof.** Photos preserve memory without becoming evidence that someone was “kind enough.” That separation is both ethically sound and easy to explain in a demo.
5. **The final event has three understandable outcomes.** Artwork, Kindness, and Photos separate the collective image, the acts, and the memories. The completed state feels like an artifact rather than an analytics dashboard.
6. **The recap protects the thesis by construction.** It uses photos only and deliberately excludes names, notes, activities, artwork, captions, and statistics. That is stronger than a privacy disclaimer alone.
7. **The Living Kiln visual identity is ownable.** Warm porcelain, ceramic gradients, editorial display type, kiln language, and tactile camera framing make Mosaic recognizable in screenshots.
8. **Monetization respects participation.** Participants stay free, while hosts pay for capacity and creation tools. RevenueCat is attached to a meaningful product boundary rather than a random feature lock.
9. **Safety is present in the actual product.** Photo deletion, reporting, blocking, blocked-user management, account deletion, and legal/support destinations exist. This matters for a group-photo product.
10. **The navigation resists feature creep.** Mosaics, Camera, and You are enough. Creation and joining are actions within the Mosaics world, not permanent tabs competing for attention.

## Core journey review

| Journey | Score | What works | Main friction/gap |
|---|---:|---|---|
| Sign in and profile setup | 7.5/10 | Apple sign-in, invitation continuity, minimal display-name step | Value proposition can be clearer before authentication; final device/account prompts must be cleared before filming |
| Mosaics home | 8.5/10 | Strong hero event, obvious “Choose an act,” secondary active/revealed sections | Empty and loading states could show more of the Living Kiln world |
| Create a Mosaic | 8.6/10 | Three editable quick-start patterns, clear Basics → Invite sequence, in-session draft restoration, persistent guest-outcome preview, and a good review/share finish | Six stages remain a commitment; drafts intentionally do not survive app termination yet |
| Join by invitation | 8.3/10 | Code → preview → join gives users confidence before commitment | Custom `mosaic://` link is fragile when the app is not installed; no universal-link/web handoff is configured |
| Complete kindness | 8.8/10 | One primary action, optional note, explicit self-attestation, equal tile placement | Success and error feedback are now semantically distinct; observed-user validation remains |
| Disposable camera | 9.0/10 | Distinctive shell, film looks, shot budget, develop/review/seal language; capture-session work is serialized off the main actor and restarts on foregrounding | Permission, interruption, and thermal recovery still require a physical-device pass |
| Reveal ceremony | 9.0/10 | The strongest emotional moment; animated, skippable, replayable, reduced-motion aware | The demo must let the reveal breathe instead of cutting too quickly |
| Completed event | 8.5/10 | Artwork/Kindness/Photos is a clear mental model; tile stories remain browsable | The first completed screen could summarize the three outcomes more cinematically |
| Gallery and safety | 8.0/10 | Clear grid, authorship/time, report reasons, and confirmed report/block/delete paths | Physical-device and VoiceOver confirmation-dialog checks remain |
| Photo recap | 8.8/10 | Clear four-stage flow, photo-only privacy rules, in-session draft restoration, music audition, duration estimate, cancellable rendering, reset confirmation, and on-device share/save | Ordering uses accessible arrows rather than drag gestures; drafts intentionally do not survive app termination yet |
| Paywall | 8.0/10 | Clear host value, participants-free promise, localized prices, restore/manage/legal links | Production products, successful purchase, entitlement refresh, and cancellation/restore must be proven on the judge path |
| You/account | 8.1/10 | Compact profile, Plus status, blocked users, safety/support, sign out/delete | Sign-out and identity changes now clear library, detail, artwork, photo, camera, and navigation state |

## Expert proxy surveys

These scores are **expert estimates**, not claims about real users. They are useful as a baseline for five quick observed sessions after submission.

### System Usability Scale proxy: 82.5/100

Estimated responses on the standard 1–5 scale after the submission-day fixes: `4, 2, 4, 1, 5, 2, 4, 2, 4, 1`, or **82.5/100**. This remains an expert proxy, not a result from participants. Quick starts, draft continuity, outcome preview, music audition, duration feedback, and cancellable recap rendering remove several avoidable wrong turns; the host flow is still necessarily longer than the participant flow.

### UMUX-Lite proxy: 5.5/7

- “Mosaic's capabilities meet my needs”: **6/7**
- “Mosaic is easy to use”: **5/7**

The product fulfills the promised group-kindness experience unusually well. Ease is one point lower because hosts face more configuration than participants and because join links rely on an installed app.

### Recommended real survey after submission

Test with at least five people: one organizer, three participants, and one person joining from a shared link. Ask each to create or join, complete an act, take a photo, find the reveal, and make a recap. After every task collect a 1–7 Single Ease Question, then administer SUS once at the end. Record completion, wrong turns, assistance required, and the exact words users use to describe “tile,” “artwork,” “camera,” and “reveal.”

## Original idea versus the product now

The earliest concept included evidence capture, private verification/approval, emotion or evidence-driven tile shapes, draggable placement, Pass the Tile, kintsugi repair, organizer moderation, impact receipts, widgets, Live Activities, and a five-tab structure.

The current product intentionally removes proof, approval, ranking, impact metrics, manual tile positioning, and extra navigation. That simplification **improves the central idea**:

- It lowers the cost of participating.
- It avoids turning kindness into surveillance or status.
- It reduces moderation and fraud theater.
- It makes every tile equal and server-authoritative.
- It gives the photo camera a clean purpose: memory, not proof.

Keep the original concept's best qualities: the object-first hero, handcrafted material, anticipation, reveal ritual, and shared artifact. Do **not** restore evidence capture, approval queues, impact scores, Pass the Tile, or additional tabs before submission. Those features make the story harder to trust and harder to demonstrate.

The remaining opportunity is aesthetic rather than conceptual: the current V3 is more usable than the concept, but several forms feel less cinematic. Add delight around the existing model instead of adding more model.

## Art inventory

| Inventory | Count | Reality today |
|---|---:|---|
| Artwork selectable in the shipping creation flow | **4** | Water Lilies; Paris Street, Rainy Day; A Sunday on La Grande Jatte; The Bedroom |
| Records in the Supabase Art Institute catalog | **112** | Catalogued backend records, not exposed by the shipping V3 creation UI |
| V2 candidate review images | **12** | Review assets, not proof that they are selectable in the app |

The honest demo claim is: **“Mosaic currently ships with four reviewed public-domain artworks.”** Do not claim 112 available artworks until the catalog endpoint, asset delivery, selection UI, attribution, accessibility text, offline behavior, and reveal packaging are connected and tested.

## Navigation and product-design assessment

The three-tab model should stay. “Mosaics” is the home and social object; “Camera” is a high-frequency event tool; “You” contains identity, billing, safety, and support. Typed routes make create/join/event/activity/photo/recap transitions understandable and maintainable.

The weak point is not tab navigation; it is **cross-context continuity**:

- A join link only understands the custom app scheme, so a recipient without Mosaic has no graceful landing experience.
- Creation now previews what guests will receive and restores work while the signed-in session remains active.
- Recap now restores selected photos, order, style, music, trim, and stage while the signed-in session remains active.
- Account-bound content is now cleared on sign-out and identity changes; keep this boundary covered as new caches are added.

Fixing those continuity gaps will do more for perceived quality than another tab or another feature.

## Visual and interaction design improvements

### Worth doing before the video if already safe

- Use a single polished demo event with a short, human title, three recognizable acts, a visually rich board, 6–10 developed photos, and a completed recap.
- Give the reveal adequate screen time and show the tile flipping into the artwork.
- Capture screenshots without simulator chrome, system prompts, debug labels, or synthetic-data ambiguity.
- Make success feedback semantic: neutral/green confirmation instead of red error styling.
- Add confirmation dialogs to delete, report, and block actions if a small verified patch is possible.

### Completed in the submission-day polish pass

- Add editable organizer quick starts for community care, classroom care, and celebrations, with suggested acts and timing.
- Keep a live “what guests will experience” card visible throughout creation.
- Restore creation and recap drafts during the signed-in session and clear both at account boundaries.
- Add recap music audition, duration estimate, confirmed reset, and render cancellation.
- Hydrate gallery photos in bounded groups of four instead of serially downloading every image.
- Move AVFoundation session configuration/start/stop to a dedicated serial queue and retry on foregrounding.

### High-value next iteration

- Create a beautiful event invite/share card and a universal web-to-app join page.
- Add encrypted cross-launch draft persistence if user testing shows it is worth the additional private-state surface.
- Generate smaller server-side gallery derivatives so the bounded loader does not need full-resolution files.
- Wire the reviewed art catalog into a searchable, attributed, accessible selector only after rights and delivery checks.
- Give empty/loading/error states their own small ceramic illustrations and tactile motion.
- Build marketing panels from the actual UI, but keep at least one honest product screenshot for judge trust.

## Repository truth audit

The [public GitHub repository](https://github.com/shellcat-com/Mosaic) still describes the earlier product: verified acts, evidence such as photos/video/receipts, evidence-shaped tiles, Pass the Tile, kintsugi, approved memories, Impact Receipts, widgets, Live Activities, and organizer moderation. The local README and current Shipaton copy now describe the shipping V3 truthfully: self-attestation, equal tiles, automatic placement, a separate photo-only camera, three completed outcomes, and a photo-only recap. Publishing that local state remains an external action.

This mismatch is the largest hackathon risk. A judge reading the public README cannot reliably understand the product shown in the current app. Before submission:

1. Push the exact V3 source, migrations, assets, setup instructions, and current documentation intended for judging.
2. Rewrite the README around the present product, not the discarded concept.
3. Remove old judge paths and example invitation codes unless they still work.
4. Explain clearly which data is live, which mode uses RevenueCat Test Store, and how a judge can reproduce the core flow.
5. Verify the repository is public and the visible license is correct from a signed-out browser.

## Shipaton requirement comparison

The official [Shipaton rules](https://revenuecat-shipaton-2026.devpost.com/rules) and [RevenueCat submission guide](https://www.revenuecat.com/blog/engineering/how-to-submit-your-app-for-shipaton) say that Next Gen is judged from the video and public open-source repository; a store release is not required for that category. The current deadline is September 30, 2026 at 11:45 PM PDT. Rules and portal requirements should be rechecked immediately before final submission.

| Requirement / judging signal | Current state | Action |
|---|---|---|
| Clear, useful, original idea | **Strong** | Lead with equal kindness becoming collective art |
| Meaningful progress and clear core function | **Strong in local V3; weak in public repo** | Align public source/README and video |
| Thoughtful RevenueCat use | **Strong design; runtime proof needed** | Show Test Store/real purchase and server-confirmed entitlement/pass behavior |
| Thoughtful technical and product care | **Strong** | Mention server-authoritative placement, privacy separation, accessibility, safety, and on-device recap |
| Public open-source repository with source/assets/instructions/license | **Warning** | Public repo exists and license is visible, but its story and likely code snapshot are stale |
| Public English YouTube/Vimeo demo under two minutes | **Fail / missing** | Record, caption, upload publicly, and place the URL in submission docs |
| App running on target platform | **Pass locally** | 46 Swift tests and 15 UI journeys pass on a clean iPhone 15 Pro Simulator |
| 1024×1024 icon | **Pass** | Keep current verified icon |
| Required submission screenshot | **Pass** | Current frameless V3 capture is exactly 1179×2556 |
| Paywall evidence | **Pass as deterministic current UI capture** | Current populated paywall capture is exactly 1179×2556; the video must still show a genuine Test Store purchase |
| Next Gen eligibility | **Unverified** | Confirm active-student/academic-email eligibility in the portal |
| Final submission completeness | **Unverified** | Complete all portal fields and use all allowed submission slots deliberately |

## App Store review comparison

The source-level release validator passes, including configuration, privacy files, icons, and catalog contracts. However, the evidence in `docs/APP_STORE_REVIEW_AUDIT.md` still leaves these blockers:

- App Store production IAP products and purchase path are not verified.
- Export-compliance answers are incomplete; the app declares non-exempt encryption because it uses encrypted artwork packages.
- App Store metadata, age rating, reviewer contact/notes, privacy answers, and review demo information are incomplete or not verified in App Store Connect.
- Distribution identity, archive/export, upload, and processed build are not proven.
- A clean shadow build now succeeds, all 46 Swift tests pass, and all 15 UI journeys pass. Distribution signing/upload remains a separate gate.

Therefore: pursue the hackathon Next Gen submission today, but do not represent the production App Store release as verified until those external and build gates are closed.

## Technical issues that affect user experience

The detailed evidence is in `CODE_AUDIT.md`. Post-audit status for the highest product-impact items is:

1. **Resolved and tested: private state at account boundaries.** Sign-out and identity changes clear routes, event library/detail, revealed artwork cache, local photo files, camera selection, billing, and API photo caches.
2. **Resolved and tested: Event Pass retry idempotency.** Premium creation now reuses one request UUID across uncertain retries and clears it after success or private-state reset.
3. **Resolved in source: camera session threading and foreground recovery.** Configuration/start/stop now run on a dedicated serial queue, and returning to the foreground retries startup.
4. **Improved in source: gallery hydration.** Protected full-resolution files are now hydrated in bounded groups of four instead of serially; true thumbnail derivatives remain a post-submission optimization.
5. **Resolved in source: recap cancellation.** Frame rendering checks cooperative cancellation and export cancellation propagates to AVFoundation; full image data can still create memory/thermal pressure at the 24-photo ceiling.
6. **Resolved in UI: destructive photo actions.** Delete, report, and block now require confirmation; reporting includes a specific reason.

## Today's execution order

### P0 — required before recording/submitting

1. Confirm the **Next Gen** lane and student eligibility. Do not depend on an App Store release for this submission.
2. Materialize the iCloud-offloaded source files, regenerate the project if required, and run a fresh full build/test on the exact commit to be published.
3. Update and push the public V3 repository and rewrite its README so every promise matches the app.
4. **Completed:** replace the legacy Shipaton screenshot and capture the populated paywall image at 1179×2556.
5. **Completed locally:** deterministic showcase events contain joined members, completed acts, developed photos, a populated board, reveal, recap, and RevenueCat premium states.
6. Record a public, captioned, English video under two minutes. Use the real running app; if any debug showcase state is used, disclose it visibly.
7. Add the public video URL, run `./scripts/validate_shipaton_submission.sh --final`, and resolve every failure.
8. Recheck the Devpost page signed out, then submit all allowed entries deliberately.

### P1 — same day only if the patch can be tested

1. ~~Clear library/detail/artwork/photo state on sign-out and identity change.~~ Completed and regression-tested.
2. ~~Persist one Event Pass request ID across retries until create succeeds or private state is reset.~~ Completed and regression-tested.
3. ~~Move camera session configuration/start/stop to a dedicated serial executor.~~ Completed; physical-device recovery remains to verify.
4. ~~Add confirmation/reason UI for delete, report, and block.~~ Completed; final UI automation is pending.
5. ~~Separate success and error feedback styling.~~ Completed with semantic symbols, color, and accessibility labels.

### P2 — after submission

1. Server-generated thumbnails and bounded cache eviction.
2. Optional encrypted cross-launch creative drafts.
3. Universal links and a web invitation landing page.
4. Optional drag ordering after observed-user testing; the accessible arrow controls remain the deterministic fallback.
5. A reviewed, attributed, searchable art catalog larger than four works.
6. Five-person observed usability study followed by SUS/UMUX-Lite.

## Recommended 100–110 second demo story

1. **0–10s — Promise:** “Small acts become one shared work of art. No rankings. No proof.” Show the Living Kiln home and the event.
2. **10–28s — Create/invite:** Briefly show activities, artwork, camera limit, reveal time, and invite share. Do not narrate every form control.
3. **28–48s — Participate:** Join from the invitation, choose an act, self-attest, and watch one equal tile land.
4. **48–63s — Remember:** Open the disposable camera, take/develop one photo, and show the sealed roll.
5. **63–82s — Reveal:** Let the completed board flip into the artwork; show Artwork, Kindness, and Photos.
6. **82–97s — Recap:** Choose photos, select a style, preview/share the photo-only recap.
7. **97–108s — Business and close:** Show the populated paywall and one successful RevenueCat-backed premium outcome. End on the artwork and the line “Kindness becomes something we made together.”

## Final recommendation

Submit Mosaic today as a focused Next Gen product: **equal, self-attested acts of kindness become a shared artwork, while a disposable camera preserves memories without turning photos into proof.** That is the version judges should see everywhere—app, README, screenshots, paywall, and video.

The app's beauty is already in its restraint and ritual. The most valuable work now is truth alignment, reliable judge access, and a clean emotional demo—not adding another feature.
