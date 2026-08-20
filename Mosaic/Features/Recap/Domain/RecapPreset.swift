import CoreGraphics
import Foundation

struct RecapPreset: Identifiable, Hashable, Sendable {
    enum VisualStyle: String, Hashable, Sendable { case standard, porcelainPrint, kilnTape, pocketKiln }
    enum Transition: String, Hashable, Sendable { case hardSnap, ceramicAdvance, warmDissolve, recordBlink, reelSpin, slideReveal }
    enum Layout: String, Hashable, Sendable { case fullBleed, triptych, ceramicFilmstrip, stackedPrints }
    enum Intro: String, Hashable, Sendable { case headline, editorial, tileCollage }
    enum Chrome: String, Hashable, Sendable { case none, communityDV, softDV, memoryCamera }
    enum Grade: String, Hashable, Sendable { case coolMonochrome, mutedOlive, softRose, tealNight, fadedAmber, goldenHour }

    let id: String
    let name: String
    let description: String
    let visualStyle: VisualStyle
    let minimumMemories: Int
    let maximumMemories: Int
    let nominalMontageDuration: TimeInterval
    let nominalClipCount: Int
    let perMemory: TimeInterval
    let transition: Transition
    let transitionDuration: TimeInterval
    let kenBurnsZoom: CGFloat
    let layout: Layout
    let intro: Intro
    let chrome: Chrome
    let grade: Grade
    let defaultMusicID: String?
}
