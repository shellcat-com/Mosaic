import Foundation

struct ChallengeRecord: Codable, Sendable {
    let id: UUID
    let name: String
    let groupName: String?
    let purpose: String
    let goal: Int
    let startAt: Date?
    let revealAt: Date
    let revealedAt: Date?
    let status: String
    let scheduleRevision: Int?
    let featuredRecapExportId: UUID?
    let invitationCode: String
    let isShowcase: Bool
    let cameraRollEnabled: Bool?
    let themeId: String?
    let themePaletteId: KinderThemePaletteID?
    let themeSeed: Int?
    let themeRevision: Int?

    init(
        id: UUID,
        name: String,
        groupName: String? = nil,
        purpose: String,
        goal: Int,
        startAt: Date? = nil,
        revealAt: Date,
        revealedAt: Date? = nil,
        status: String,
        scheduleRevision: Int? = nil,
        featuredRecapExportId: UUID? = nil,
        invitationCode: String,
        isShowcase: Bool,
        cameraRollEnabled: Bool? = nil,
        themeId: String? = nil,
        themePaletteId: KinderThemePaletteID? = nil,
        themeSeed: Int? = nil,
        themeRevision: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.groupName = groupName
        self.purpose = purpose
        self.goal = goal
        self.startAt = startAt
        self.revealAt = revealAt
        self.revealedAt = revealedAt
        self.status = status
        self.scheduleRevision = scheduleRevision
        self.featuredRecapExportId = featuredRecapExportId
        self.invitationCode = invitationCode
        self.isShowcase = isShowcase
        self.cameraRollEnabled = cameraRollEnabled
        self.themeId = themeId
        self.themePaletteId = themePaletteId
        self.themeSeed = themeSeed
        self.themeRevision = themeRevision
    }

    enum CodingKeys: String, CodingKey {
        case id, name, purpose, goal, status
        case groupName = "group_name"
        case startAt = "start_at"
        case revealAt = "reveal_at"
        case revealedAt = "revealed_at"
        case scheduleRevision = "schedule_revision"
        case featuredRecapExportId = "featured_recap_export_id"
        case invitationCode = "invitation_code"
        case isShowcase = "is_showcase"
        case cameraRollEnabled = "camera_roll_enabled"
        case themeId = "theme_id"
        case themePaletteId = "theme_palette_id"
        case themeSeed = "theme_seed"
        case themeRevision = "theme_revision"
    }

    var effectiveStartAt: Date {
        startAt ?? Calendar.current.date(byAdding: .day, value: -7, to: revealAt) ?? revealAt
    }

    var themeSelection: ThemeSelection {
        guard let themeId else { return .fallback }
        let theme = KinderThemeCatalog.theme(id: themeId)
        return ThemeSelection(
            themeID: theme.id,
            paletteID: themePaletteId ?? .signature,
            seed: themeSeed ?? theme.seed,
            revision: themeRevision ?? KinderThemeCatalog.revision
        )
    }
}

struct InvitationPreview: Codable, Hashable, Sendable {
    let challengeID: UUID
    let code: String
    let name: String
    let groupName: String
    let purpose: String
    let goal: Int
    let startAt: Date?
    let revealAt: Date
    let status: String
    let theme: ThemeSelection

    enum CodingKeys: String, CodingKey {
        case code, name, purpose, goal, status, theme
        case challengeID = "challenge_id"
        case groupName = "group_name"
        case startAt = "start_at"
        case revealAt = "reveal_at"
    }

    init(
        challengeID: UUID,
        code: String,
        name: String,
        groupName: String,
        purpose: String,
        goal: Int,
        startAt: Date?,
        revealAt: Date,
        status: String,
        theme: ThemeSelection = .fallback
    ) {
        self.challengeID = challengeID
        self.code = code
        self.name = name
        self.groupName = groupName
        self.purpose = purpose
        self.goal = goal
        self.startAt = startAt
        self.revealAt = revealAt
        self.status = status
        self.theme = theme
    }
}

struct InvitationPreviewResponse: Codable, Sendable {
    let invitation: InvitationPreview
}

struct ContributionChallengeRecord: Decodable, Sendable {
    let challengeId: UUID
    enum CodingKeys: String, CodingKey { case challengeId = "challenge_id" }
}

struct RecapListRecord: Decodable, Sendable {
    let id: UUID
    let challengeId: UUID
    let status: String
    let thumbnailPath: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case challengeId = "challenge_id"
        case thumbnailPath = "thumbnail_path"
    }
}

struct MissionRecord: Codable, Sendable {
    let id: UUID
    let challengeId: UUID
    let title: String
    let detail: String
    let category: MissionCategory
    let minutes: Int
    let effort: String
    let acceptedEvidence: [EvidenceMethod]
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, title, detail, category, minutes, effort
        case challengeId = "challenge_id"
        case acceptedEvidence = "accepted_evidence"
        case sortOrder = "sort_order"
    }

    var mission: Mission {
        Mission(id: id, title: title, detail: detail, category: category, minutes: minutes, effort: effort, evidence: acceptedEvidence)
    }
}

struct ContributionRecord: Codable, Sendable {
    let id: UUID
    let challengeId: UUID
    let missionId: UUID
    let emotion: Emotion
    let evidenceMethod: EvidenceMethod
    let status: ContributionStatus
    let verificationLevel: String?
    let tilePosition: Int?

    enum CodingKeys: String, CodingKey {
        case id, emotion, status
        case challengeId = "challenge_id"
        case missionId = "mission_id"
        case evidenceMethod = "evidence_method"
        case verificationLevel = "verification_level"
        case tilePosition = "tile_position"
    }
}

struct DemoBootstrapResponse: Codable, Sendable {
    let showcase: ChallengeRecord
    let sandbox: ChallengeRecord?
}

struct ChallengeResponse: Codable, Sendable {
    let challenge: ChallengeRecord
}

struct ContributionResponse: Codable, Sendable {
    let contribution: ContributionRecord
}

struct PrepareContributionResponse: Codable, Sendable {
    struct Upload: Codable, Sendable {
        let path: String
        let token: String
        let signedUrl: URL?

        enum CodingKeys: String, CodingKey {
            case path, token
            case signedUrl = "signedUrl"
        }
    }

    let contributionId: UUID
    let upload: Upload?
}

struct EvidenceDraft: Sendable {
    let id: UUID
    let challengeID: UUID
    let missionID: UUID
    let emotion: Emotion
    let method: EvidenceMethod
    let reflection: String?
    let mediaData: Data?
    let mimeType: String?
    let durationSeconds: Double?
    let includeMemory: Bool
    let showIdentity: Bool
    let exportConsent: Bool
}

enum EvidenceUploadValidationError: LocalizedError, Equatable {
    case missingMedia
    case imageTooLarge
    case videoTooLarge
    case invalidVideoDuration

    var errorDescription: String? {
        switch self {
        case .missingMedia: "Choose evidence before continuing."
        case .imageTooLarge: "Images must be 10 MB or smaller."
        case .videoTooLarge: "Videos must be 25 MB or smaller."
        case .invalidVideoDuration: "Videos must be 10 seconds or shorter."
        }
    }
}

struct EvidenceUploadPolicy {
    static let maximumImageBytes = 10 * 1_024 * 1_024
    static let maximumVideoBytes = 25 * 1_024 * 1_024
    static let maximumVideoDuration = 10.0

    static func validate(method: EvidenceMethod, byteCount: Int?, duration: Double?) throws {
        switch method {
        case .photo, .receipt:
            guard let byteCount else { throw EvidenceUploadValidationError.missingMedia }
            guard byteCount <= maximumImageBytes else { throw EvidenceUploadValidationError.imageTooLarge }
        case .video:
            guard let byteCount else { throw EvidenceUploadValidationError.missingMedia }
            guard byteCount <= maximumVideoBytes else { throw EvidenceUploadValidationError.videoTooLarge }
            guard let duration, duration > 0, duration <= maximumVideoDuration else {
                throw EvidenceUploadValidationError.invalidVideoDuration
            }
        case .reflection, .organizer, .partner:
            break
        }
    }
}

enum MosaicBackendState: Equatable, Sendable {
    case localPreview
    case connecting
    case live
    case cached(message: String)
    case failed(message: String)

    var isLive: Bool { self == .live }
}
