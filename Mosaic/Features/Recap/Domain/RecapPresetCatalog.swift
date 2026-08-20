import Foundation

enum RecapPresetCatalog {
    static let quietMoments = RecapPreset(
        id: "quiet", name: "Quiet Moments", description: "Small moments, held with care.", visualStyle: .standard, minimumMemories: 8,
        maximumMemories: 14, nominalMontageDuration: 8, nominalClipCount: 10, perMemory: 0.8,
        transition: .hardSnap, transitionDuration: 0, kenBurnsZoom: 1.06, layout: .fullBleed,
        intro: .headline, chrome: .communityDV, grade: .coolMonochrome, defaultMusicID: "fresh"
    )
    static let communityGrid = RecapPreset(
        id: "grid", name: "Community Grid", description: "Many hands, one shared rhythm.", visualStyle: .standard, minimumMemories: 6,
        maximumMemories: 12, nominalMontageDuration: 14, nominalClipCount: 9, perMemory: 1.55,
        transition: .ceramicAdvance, transitionDuration: 0, kenBurnsZoom: 1.06, layout: .triptych,
        intro: .editorial, chrome: .none, grade: .mutedOlive, defaultMusicID: "spark"
    )
    static let kindnessBloom = RecapPreset(
        id: "bloom", name: "Kindness Bloom", description: "Warm memories opening together.", visualStyle: .standard, minimumMemories: 6,
        maximumMemories: 12, nominalMontageDuration: 13, nominalClipCount: 9, perMemory: 1.44,
        transition: .warmDissolve, transitionDuration: 0.5, kenBurnsZoom: 1.14, layout: .fullBleed,
        intro: .headline, chrome: .softDV, grade: .softRose, defaultMusicID: "anywhere"
    )
    static let actionDiary = RecapPreset(
        id: "diary", name: "Action Diary", description: "A living record of showing up.", visualStyle: .standard, minimumMemories: 7,
        maximumMemories: 15, nominalMontageDuration: 14, nominalClipCount: 10, perMemory: 1.4,
        transition: .recordBlink, transitionDuration: 0, kenBurnsZoom: 1.06, layout: .fullBleed,
        intro: .headline, chrome: .memoryCamera, grade: .tealNight, defaultMusicID: "zone"
    )
    static let tileStrip = RecapPreset(
        id: "strip", name: "Tile Strip", description: "A tactile reel of the community.", visualStyle: .standard, minimumMemories: 6,
        maximumMemories: 12, nominalMontageDuration: 10, nominalClipCount: 8, perMemory: 1.25,
        transition: .reelSpin, transitionDuration: 0.4, kenBurnsZoom: 1.14, layout: .ceramicFilmstrip,
        intro: .tileCollage, chrome: .none, grade: .fadedAmber, defaultMusicID: "rise"
    )
    static let goldenMosaic = RecapPreset(
        id: "golden", name: "Golden Mosaic", description: "The complete story, revealed in light.", visualStyle: .standard, minimumMemories: 8,
        maximumMemories: 16, nominalMontageDuration: 16, nominalClipCount: 10, perMemory: 1.6,
        transition: .slideReveal, transitionDuration: 0.4, kenBurnsZoom: 1.14, layout: .stackedPrints,
        intro: .editorial, chrome: .none, grade: .goldenHour, defaultMusicID: "summer"
    )

    static let porcelainPrint = RecapPreset(
        id: "porcelain-print", name: "Porcelain Print", description: "Warm memories, developed on porcelain.", visualStyle: .porcelainPrint,
        minimumMemories: 6, maximumMemories: 14, nominalMontageDuration: 12.15, nominalClipCount: 9, perMemory: 1.35,
        transition: .warmDissolve, transitionDuration: 0.35, kenBurnsZoom: 1.06, layout: .stackedPrints,
        intro: .editorial, chrome: .none, grade: .goldenHour, defaultMusicID: "fresh"
    )

    static let kilnTape = RecapPreset(
        id: "kiln-tape", name: "Kiln Tape", description: "A fired-night record of showing up.", visualStyle: .kilnTape,
        minimumMemories: 7, maximumMemories: 15, nominalMontageDuration: 12, nominalClipCount: 10, perMemory: 1.2,
        transition: .hardSnap, transitionDuration: 0, kenBurnsZoom: 1.05, layout: .fullBleed,
        intro: .headline, chrome: .communityDV, grade: .tealNight, defaultMusicID: "summer"
    )

    static let pocketKiln = RecapPreset(
        id: "pocket-kiln", name: "Pocket Kiln", description: "A handmade camera for collective memory.", visualStyle: .pocketKiln,
        minimumMemories: 6, maximumMemories: 12, nominalMontageDuration: 11.2, nominalClipCount: 8, perMemory: 1.4,
        transition: .recordBlink, transitionDuration: 0.18, kenBurnsZoom: 1.05, layout: .fullBleed,
        intro: .headline, chrome: .memoryCamera, grade: .fadedAmber, defaultMusicID: "spark"
    )

    static let all = [goldenMosaic, porcelainPrint, kilnTape, pocketKiln, quietMoments, communityGrid, kindnessBloom, actionDiary, tileStrip]
    static let recommended = goldenMosaic
}
