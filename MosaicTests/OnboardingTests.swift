import Testing
import UIKit
@testable import Mosaic

@MainActor
struct OnboardingTests {
    @Test func scenesUseTheAdaptiveThreePageStory() {
        let scenes = OnboardingScene.all

        #expect(scenes.count == 3)
        #expect(scenes.map(\.artwork.artworkID) == [27992, 16568, 28560])
        #expect(scenes.map(\.headlineAccent) == [
            "Make it real.",
            "One honest memory.",
            "made together."
        ])
        #expect(scenes.map(\.overlay) == [.equalContribution, .privacyChoice, .sharedReveal])
        #expect(scenes.last?.buttonTitle == "Choose how to begin")
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

    @Test func onboardingOffersOnlyImplementedPrivacyChoices() {
        #expect(ParticipantPrivacy.onboardingChoices == [.firstName, .anonymous])
        #expect(!ParticipantPrivacy.onboardingChoices.contains(.quiet))
        #expect(ParticipantPrivacy.firstName.rawValue == "first_name")
    }

    @Test func completionIsVersionedAndPersisted() throws {
        let suite = "MosaicTests.Onboarding.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = OnboardingProgressStore(defaults: defaults)

        #expect(!progress.hasCompletedCurrentIntro)
        progress.markIntroCompleted()
        #expect(progress.hasCompletedCurrentIntro)
        #expect(defaults.integer(forKey: OnboardingProgressStore.key) == OnboardingProgressStore.currentVersion)
    }

    @Test func invitationRoutesNormalizeCustomAndGitHubPagesLinks() {
        #expect(EventRouteParser.parse(URL(string: "mosaic://join/kind42")!) == .join("KIND42"))
        #expect(EventRouteParser.parse(URL(string: "https://shellcat-com.github.io/Mosaic/?join=a1b2c3")!) == .join("A1B2C3"))
        #expect(EventRouteParser.parse(URL(string: "https://example.com/join/KIND42")!) == nil)
        #expect(EventRouteParser.parse(URL(string: "https://mosaic.app/join/KIND42")!) == nil)
        #expect(EventRouteParser.parse(URL(string: "https://shellcat-com.github.io/Mosaic/?join=not-valid!")!) == nil)
        #expect(EventRouteParser.parse(URL(string: "https://shellcat-com.github.io/Other/?join=KIND42")!) == nil)
        #expect(EventRouteParser.parse(URL(string: "https://shellcat-com.github.io/Other/Mosaic/?join=KIND42")!) == nil)
        #expect(EventRouteParser.parse(URL(string: "mosaic://unrelated/KIND42")!) == nil)
    }

    @Test func manuallyEnteredInvitationCodesAreTrimmedUppercasedAndBounded() {
        #expect(AppStore.normalizedInvitationCode("  kind42\n") == "KIND42")
        #expect(AppStore.isValidInvitationCode("KIND42"))
        #expect(AppStore.isValidInvitationCode("A1B2C3D4E5F6"))
        #expect(!AppStore.isValidInvitationCode(""))
        #expect(!AppStore.isValidInvitationCode("NOT-VALID"))
        #expect(!AppStore.isValidInvitationCode("A1B2C3D4E5F67"))
    }
}
