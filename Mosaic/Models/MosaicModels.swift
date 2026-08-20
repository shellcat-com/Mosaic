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

struct ContributionMemory: Hashable, Codable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case photo, reflection, photoWithNote, tileOnly
    }

    let kind: Kind
    let note: String?
    let localAssetName: String?
    let mediaVersion: Int
    let consentVersion: Int
    let recapConsent: Bool
    let attributionAllowed: Bool

    init(
        kind: Kind,
        note: String? = nil,
        localAssetName: String? = nil,
        mediaVersion: Int = 1,
        consentVersion: Int = 1,
        recapConsent: Bool,
        attributionAllowed: Bool
    ) {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = kind
        self.note = trimmed?.isEmpty == false ? trimmed : nil
        self.localAssetName = localAssetName
        self.mediaVersion = mediaVersion
        self.consentVersion = consentVersion
        self.recapConsent = recapConsent
        self.attributionAllowed = attributionAllowed
    }
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
    let participantID: UUID
    let createdAt: Date
    let memory: ContributionMemory?
    let isDeleted: Bool
    let isReported: Bool
    let contributorIsBlocked: Bool

    init(
        id: UUID,
        mission: Mission,
        emotion: Emotion,
        evidence: EvidenceMethod,
        contributor: String?,
        sharedMemory: Bool,
        isRevived: Bool,
        status: ContributionStatus = .placed,
        tilePosition: Int? = nil,
        participantID: UUID? = nil,
        createdAt: Date = .now,
        memory: ContributionMemory? = nil,
        isDeleted: Bool = false,
        isReported: Bool = false,
        contributorIsBlocked: Bool = false
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
        self.participantID = participantID ?? id
        self.createdAt = createdAt
        self.memory = memory
        self.isDeleted = isDeleted
        self.isReported = isReported
        self.contributorIsBlocked = contributorIsBlocked
    }
}

struct KindnessChallenge: Identifiable, Sendable {
    let id: UUID
    var name: String
    var groupName: String
    var purpose: String
    var goal: Int
    var startDate: Date
    var revealDate: Date
    var revealedAt: Date?
    var serverStatus: String
    var scheduleRevision: Int
    var recapAvailability: RecapAvailability
    var recapThumbnailFilename: String?
    var invitationCode: String
    var contributions: [TileContribution]
    var theme: ThemeSelection
    var cameraRollEnabled: Bool
    var sharedMoments: [SharedMoment]
    var mosaicVersion: Int
    var impactReceiptVersion: Int

    init(
        id: UUID = UUID(),
        name: String,
        groupName: String = "Mosaic Community",
        purpose: String,
        goal: Int,
        startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now,
        revealDate: Date,
        revealedAt: Date? = nil,
        serverStatus: String = "active",
        scheduleRevision: Int = 1,
        recapAvailability: RecapAvailability = .unavailable,
        recapThumbnailFilename: String? = nil,
        invitationCode: String,
        contributions: [TileContribution],
        theme: ThemeSelection = .fallback,
        cameraRollEnabled: Bool = true,
        sharedMoments: [SharedMoment] = [],
        mosaicVersion: Int = 1,
        impactReceiptVersion: Int = 1
    ) {
        self.id = id
        self.name = name
        self.groupName = groupName
        self.purpose = purpose
        self.goal = goal
        self.startDate = startDate
        self.revealDate = revealDate
        self.revealedAt = revealedAt
        self.serverStatus = serverStatus
        self.scheduleRevision = scheduleRevision
        self.recapAvailability = recapAvailability
        self.recapThumbnailFilename = recapThumbnailFilename
        self.invitationCode = invitationCode
        self.contributions = contributions
        self.theme = theme
        self.cameraRollEnabled = cameraRollEnabled
        self.sharedMoments = sharedMoments
        self.mosaicVersion = mosaicVersion
        self.impactReceiptVersion = impactReceiptVersion
    }

    var summary: ChallengeSummary {
        ChallengeSummary(
            id: id,
            name: name,
            groupName: groupName,
            purpose: purpose,
            startAt: startDate,
            revealAt: revealDate,
            revealedAt: revealedAt,
            serverStatus: serverStatus,
            scheduleRevision: scheduleRevision,
            contributionCount: contributions.count,
            goal: goal,
            recapAvailability: recapAvailability,
            recapThumbnailFilename: recapThumbnailFilename,
            theme: theme
        )
    }
}
