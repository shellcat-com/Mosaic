import Foundation

enum MosaicPhase: String, Codable, Hashable, Sendable {
    case scheduled
    case active
    case full
    case revealed
    case deleted

    static func resolve(startAt: Date, revealAt: Date, contributionCount: Int, goal: Int, now: Date = .now) -> Self {
        if now >= revealAt { return .revealed }
        if now < startAt { return .scheduled }
        if contributionCount >= goal { return .full }
        return .active
    }

    var acceptsJoining: Bool { self != .revealed && self != .deleted }
    var acceptsPhotos: Bool { self == .scheduled || self == .active || self == .full }
    var acceptsContributions: Bool { self == .active }
}

enum FilmLookID: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case sunwashed
    case garden
    case afterglow

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var detail: String {
        switch self {
        case .sunwashed: "Warm highlights and softly faded color"
        case .garden: "Quiet greens and low-contrast shadows"
        case .afterglow: "Rosy warmth with a gentle evening bloom"
        }
    }
}

struct CuratedArtwork: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let artist: String
    let assetName: String
    let sourceURL: URL
    let license: String
    let altText: String

    static let collection: [Self] = [
        .init(id: artworkID(1), title: "Water Lilies", artist: "Claude Monet", assetName: "OnboardingWaterLilies", sourceURL: artworkURL("16568/water-lilies"), license: "CC0 / Public Domain", altText: "Water lilies floating across a blue-green pond"),
        .init(id: artworkID(2), title: "Paris Street; Rainy Day", artist: "Gustave Caillebotte", assetName: "OnboardingParisStreet", sourceURL: artworkURL("20684/paris-street-rainy-day"), license: "CC0 / Public Domain", altText: "People walking with umbrellas on a broad Paris street"),
        .init(id: artworkID(3), title: "A Sunday on La Grande Jatte", artist: "Georges Seurat", assetName: "OnboardingLaGrandeJatte", sourceURL: artworkURL("27992/a-sunday-on-la-grande-jatte-1884"), license: "CC0 / Public Domain", altText: "People relaxing by the river on a sunny afternoon"),
        .init(id: artworkID(4), title: "The Bedroom", artist: "Vincent van Gogh", assetName: "OnboardingBedroom", sourceURL: artworkURL("28560/the-bedroom"), license: "CC0 / Public Domain", altText: "A colorful painted bedroom with a wooden bed")
    ]

    private static func artworkID(_ suffix: UInt8) -> UUID {
        UUID(uuid: (0xA0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, suffix))
    }

    private static func artworkURL(_ path: String) -> URL {
        URL(string: "https://www.artic.edu/artworks/\(path)") ?? URL(fileURLWithPath: "/")
    }
}

struct MosaicSummary: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let communityName: String
    let description: String
    let startAt: Date
    let revealAt: Date
    let goal: Int
    let contributionCount: Int
    let photoCount: Int
    let filmLookID: FilmLookID
    let shotLimit: Int
    let artwork: CuratedArtwork
    let isCreator: Bool
    var accessSource: MosaicAccessSource = .free
    var premiumCapabilities: MosaicPremiumCapabilities = .free

    var phase: MosaicPhase {
        .resolve(startAt: startAt, revealAt: revealAt, contributionCount: contributionCount, goal: goal)
    }
}

struct MosaicEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var communityName: String
    var description: String
    let creatorID: UUID
    let invitationCode: String
    let invitationURL: URL
    let startAt: Date
    let revealAt: Date
    let goal: Int
    let filmLookID: FilmLookID
    let shotLimit: Int
    let artwork: CuratedArtwork
    var activities: [KindnessActivity]
    var contributions: [KindnessContribution]
    var contributionCount: Int
    var occupiedTilePositions: [Int]
    var photos: [EventPhoto]
    let memberCount: Int
    let isCreator: Bool
    var accessSource: MosaicAccessSource = .free
    var premiumCapabilities: MosaicPremiumCapabilities = .free

    var phase: MosaicPhase {
        .resolve(startAt: startAt, revealAt: revealAt, contributionCount: contributionCount, goal: goal)
    }

    var summary: MosaicSummary {
        var result = MosaicSummary(
            id: id, name: name, communityName: communityName, description: description,
            startAt: startAt, revealAt: revealAt, goal: goal,
            contributionCount: contributionCount, photoCount: photos.count,
            filmLookID: filmLookID, shotLimit: shotLimit, artwork: artwork, isCreator: isCreator
        )
        result.accessSource = accessSource
        result.premiumCapabilities = premiumCapabilities
        return result
    }
}

struct MosaicDraft: Hashable, Sendable {
    var name = ""
    var communityName = ""
    var description = ""
    var activities: [KindnessActivityDraft] = [.init()]
    var artwork = CuratedArtwork.collection[0]
    var filmLookID = FilmLookID.sunwashed
    var shotLimit = 12
    var startAt = Date.now.addingTimeInterval(3_600)
    var revealAt = Date.now.addingTimeInterval(60 * 60 * 24 * 7)
    var goal = 25

    static let supportedGoals = [9, 16, 25, 36, 49, 64, 81, 100]
    static let supportedShotLimits = [12, 24, 36]

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !communityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        activities.contains { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        Self.supportedGoals.contains(goal) && Self.supportedShotLimits.contains(shotLimit) && revealAt > startAt
    }
}

struct MosaicInvitationPreview: Codable, Hashable, Sendable {
    let code: String
    let name: String
    let communityName: String
    let description: String
    let revealAt: Date
    let artwork: CuratedArtwork
    let memberCount: Int
}
