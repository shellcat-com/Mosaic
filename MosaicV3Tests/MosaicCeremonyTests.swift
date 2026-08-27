import Foundation
import Testing
@testable import Mosaic

@MainActor
struct MosaicCeremonyTests {
    @Test
    func placementSkipResolvesToCompleted() {
        let playback = PlacementCeremonyModel()
        playback.play(reduceMotion: false)
        playback.skip()
        #expect(playback.phase == .completed)
    }

    @Test
    func placementReduceMotionCompletesImmediately() {
        let playback = PlacementCeremonyModel()
        playback.play(reduceMotion: true)
        #expect(playback.phase == .completed)
    }
}
