import Foundation
import SwiftUI

enum ParticipantPrivacy: String, Codable, CaseIterable, Sendable {
    case firstName = "first_name"
    case anonymous
    case quiet

    static var onboardingChoices: [ParticipantPrivacy] { [.firstName, .anonymous] }

    var title: String {
        switch self {
        case .firstName: "Use my first name"
        case .anonymous: "Join anonymously"
        case .quiet: "Quiet participant"
        }
    }

    var detail: String {
        switch self {
        case .firstName: "Your first name can appear beside memories you separately approve."
        case .anonymous: "Your tile still counts, but your name stays hidden from the group."
        case .quiet: "Legacy privacy mode"
        }
    }

    var profileLabel: String {
        switch self {
        case .firstName: "First name"
        case .anonymous: "Anonymous"
        case .quiet: "Quiet participant"
        }
    }
}

enum AppEntryState: Equatable, Sendable {
    case launching
    case intro
    case entryChoice
    case resolvingInvitation(String)
    case invitationPreview(InvitationPreview)
    case joining(InvitationPreview)
    case main
}

struct OnboardingProgressStore {
    static let currentVersion = 2
    static let key = "mosaic.onboarding.completed-version"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedCurrentIntro: Bool {
        defaults.integer(forKey: Self.key) >= Self.currentVersion
    }

    func markIntroCompleted() {
        defaults.set(Self.currentVersion, forKey: Self.key)
    }

    func reset() {
        defaults.removeObject(forKey: Self.key)
    }
}

enum ContextualEducationProgress {
    static let passTheTileShownKey = "mosaic.education.pass-the-tile-shown"
}

struct ArtworkAttribution: Identifiable, Hashable {
    let artworkID: Int
    let assetName: String
    let title: String
    let artist: String
    let date: String
    let sourceURL: URL
    let accessibilityDescription: String
    let isPublicDomain: Bool

    var id: Int { artworkID }

    var requestedCredit: String {
        "\(artist). \(title), \(date). The Art Institute of Chicago."
    }
}

enum OnboardingOverlay: Hashable {
    case equalContribution
    case privacyChoice
    case sharedReveal
}

struct OnboardingScene: Identifiable {
    let id: Int
    let eyebrow: String
    let headlineLead: String
    let headlineAccent: String
    let supportingCopy: String
    let buttonTitle: String
    let artwork: ArtworkAttribution
    let overlay: OnboardingOverlay
    let imageAlignment: Alignment

    static let all: [OnboardingScene] = [
        OnboardingScene(
            id: 0,
            eyebrow: "Every act belongs",
            headlineLead: "One small act. ",
            headlineAccent: "One equal tile.",
            supportingCopy: "Complete a mission and your kindness becomes part of the group artwork—never bigger, never ranked.",
            buttonTitle: "Begin",
            artwork: ArtworkAttribution(
                artworkID: 27992,
                assetName: "OnboardingLaGrandeJatte",
                title: "A Sunday on La Grande Jatte — 1884",
                artist: "Georges Seurat",
                date: "1884–86, border added 1888–89",
                sourceURL: URL(string: "https://www.artic.edu/artworks/27992/a-sunday-on-la-grande-jatte-1884")!,
                accessibilityDescription: "A large pointillist painting of people relaxing together in a crowded riverside park.",
                isPublicDomain: true
            ),
            overlay: .equalContribution,
            imageAlignment: .center
        ),
        OnboardingScene(
            id: 1,
            eyebrow: "You stay in control",
            headlineLead: "Private by default. ",
            headlineAccent: "Shared by choice.",
            supportingCopy: "Evidence goes only to organizers. Memories and your name appear only when you allow them.",
            buttonTitle: "Continue",
            artwork: ArtworkAttribution(
                artworkID: 16568,
                assetName: "OnboardingWaterLilies",
                title: "Water Lilies",
                artist: "Claude Monet",
                date: "1906",
                sourceURL: URL(string: "https://www.artic.edu/artworks/16568/water-lilies")!,
                accessibilityDescription: "A close view of a blue-green pond scattered with softly painted pink and white water lilies.",
                isPublicDomain: true
            ),
            overlay: .privacyChoice,
            imageAlignment: .center
        ),
        OnboardingScene(
            id: 2,
            eyebrow: "Open it together",
            headlineLead: "Reveal what you made ",
            headlineAccent: "together.",
            supportingCopy: "When the challenge ends, every verified tile opens into one shared artwork and recap.",
            buttonTitle: "Choose how to begin",
            artwork: ArtworkAttribution(
                artworkID: 28560,
                assetName: "OnboardingBedroom",
                title: "The Bedroom",
                artist: "Vincent van Gogh",
                date: "1889",
                sourceURL: URL(string: "https://www.artic.edu/artworks/28560/the-bedroom")!,
                accessibilityDescription: "A brightly painted bedroom with blue walls, a green window, a wooden bed, and red bedding.",
                isPublicDomain: true
            ),
            overlay: .sharedReveal,
            imageAlignment: .center
        )
    ]
}
