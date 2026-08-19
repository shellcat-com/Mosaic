import Testing
import UIKit
@testable import Mosaic

@MainActor
struct OnboardingTests {
    @Test func scenesUseTheApprovedOrderAndCopy() {
        let scenes = OnboardingScene.all

        #expect(scenes.count == 4)
        #expect(scenes.map(\.artwork.artworkID) == [27992, 16568, 20684, 28560])
        #expect(scenes.map(\.headlineAccent) == [
            "shared masterpiece.",
            "leaves a mark.",
            "forward.",
            "A Kinder Block."
        ])
        #expect(scenes.last?.overlay == .invitation)
        #expect(scenes.last?.buttonTitle == "Join the challenge")
    }

    @Test func everyArtworkIsBundledAndFullyAttributed() {
        for scene in OnboardingScene.all {
            let artwork = scene.artwork

            #expect(artwork.isPublicDomain)
            #expect(!artwork.title.isEmpty)
            #expect(!artwork.artist.isEmpty)
            #expect(!artwork.date.isEmpty)
            #expect(!artwork.accessibilityDescription.isEmpty)
            #expect(artwork.sourceURL.host == "www.artic.edu")
            #expect(UIImage(named: artwork.assetName) != nil)
        }
    }

    @Test func invitationRemainsTheSkipDestinationWithoutJoining() {
        let store = AppStore()
        let invitationIndex = OnboardingScene.all.count - 1

        #expect(invitationIndex == 3)
        #expect(OnboardingScene.all[invitationIndex].overlay == .invitation)
        #expect(!store.hasJoined)
    }
}
