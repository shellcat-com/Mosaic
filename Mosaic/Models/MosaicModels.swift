import SwiftUI

enum MissionCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case encouragement, giving, community, teaching, support, connection
    var id: String { rawValue }

    var title: String {
        switch self {
        case .encouragement: "Encourage"
        case .giving: "Give"
        case .community: "Community"
        case .teaching: "Teach"
        case .support: "Support"
        case .connection: "Connect"
        }
    }

    var symbol: String {
        switch self {
        case .encouragement: "heart"
        case .giving: "gift"
        case .community: "leaf"
        case .teaching: "lightbulb"
        case .support: "hands.sparkles"
        case .connection: "person.2"
        }
    }
}

enum EvidenceMethod: String, CaseIterable, Codable, Identifiable, Sendable {
    case reflection, photo, video, receipt, partner, organizer
    var id: String { rawValue }

    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .reflection: "text.quote"
        case .photo: "camera"
        case .video: "video"
        case .receipt: "doc.text.viewfinder"
        case .partner: "person.badge.checkmark"
        case .organizer: "checkmark.seal"
        }
    }
}

enum Emotion: String, CaseIterable, Codable, Identifiable, Sendable {
    case hopeful, joyful, caring, calm
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .hopeful: MosaicTheme.sky
        case .joyful: MosaicTheme.persimmon
        case .caring: MosaicTheme.rose
        case .calm: MosaicTheme.sage
        }
    }
}

enum ContributionStatus: String, Codable, Sendable {
    case draft
    case pendingReview = "pending_review"
    case selfAttested = "self_attested"
    case verified
    case rejected
    case placed
    case revealed
    case archived

    var needsModeration: Bool { self == .pendingReview }
    var canPlace: Bool { self == .selfAttested || self == .verified || self == .placed }
}

struct Mission: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let category: MissionCategory
    let minutes: Int
    let effort: String
    let evidence: [EvidenceMethod]

    init(id: UUID = UUID(), title: String, detail: String, category: MissionCategory, minutes: Int, effort: String, evidence: [EvidenceMethod]) {
        self.id = id
        self.title = title
        self.detail = detail
        self.category = category
        self.minutes = minutes
        self.effort = effort
        self.evidence = evidence
    }
}

struct TileContribution: Identifiable, Hashable, Sendable {
    let id: UUID
    let mission: Mission
    let emotion: Emotion
    let evidence: EvidenceMethod
    let contributor: String?
    let sharedMemory: Bool
    let isRevived: Bool
    let status: ContributionStatus
    let tilePosition: Int?

    init(
        id: UUID,
        mission: Mission,
        emotion: Emotion,
        evidence: EvidenceMethod,
        contributor: String?,
        sharedMemory: Bool,
        isRevived: Bool,
        status: ContributionStatus = .placed,
        tilePosition: Int? = nil
    ) {
        self.id = id
        self.mission = mission
        self.emotion = emotion
        self.evidence = evidence
        self.contributor = contributor
        self.sharedMemory = sharedMemory
        self.isRevived = isRevived
        self.status = status
        self.tilePosition = tilePosition
    }
}

struct KindnessChallenge: Identifiable, Sendable {
    let id: UUID
    var name: String
    var purpose: String
    var goal: Int
    var revealDate: Date
    var invitationCode: String
    var contributions: [TileContribution]

    init(
        id: UUID = UUID(),
        name: String,
        purpose: String,
        goal: Int,
        revealDate: Date,
        invitationCode: String,
        contributions: [TileContribution]
    ) {
        self.id = id
        self.name = name
        self.purpose = purpose
        self.goal = goal
        self.revealDate = revealDate
        self.invitationCode = invitationCode
        self.contributions = contributions
    }
}
