import SwiftUI

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
    case ceramicGrid
    case passTheTile
    case invitation
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
            eyebrow: "Our vision",
            headlineLead: "Small acts become a ",
            headlineAccent: "shared masterpiece.",
            supportingCopy: "Every act of care becomes an equal part of something beautiful.",
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
            eyebrow: "Add your tile",
            headlineLead: "Every kindness ",
            headlineAccent: "leaves a mark.",
            supportingCopy: "Your action becomes one equal tile in the living artwork.",
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
            overlay: .ceramicGrid,
            imageAlignment: .center
        ),
        OnboardingScene(
            id: 2,
            eyebrow: "Grow together",
            headlineLead: "Pass it ",
            headlineAccent: "forward.",
            supportingCopy: "Invite someone else and watch the artwork grow—without scores or rankings.",
            buttonTitle: "Continue",
            artwork: ArtworkAttribution(
                artworkID: 20684,
                assetName: "OnboardingParisStreet",
                title: "Paris Street; Rainy Day",
                artist: "Gustave Caillebotte",
                date: "1877",
                sourceURL: URL(string: "https://www.artic.edu/artworks/20684/paris-street-rainy-day")!,
                accessibilityDescription: "People carrying umbrellas cross a broad cobblestone intersection on a rainy day in Paris.",
                isPublicDomain: true
            ),
            overlay: .passTheTile,
            imageAlignment: .center
        ),
        OnboardingScene(
            id: 3,
            eyebrow: "You’re invited",
            headlineLead: "You’re invited to ",
            headlineAccent: "A Kinder Block.",
            supportingCopy: "Join your neighbors and help turn small acts of care into one living artwork.",
            buttonTitle: "Join the challenge",
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
            overlay: .invitation,
            imageAlignment: .center
        )
    ]
}
