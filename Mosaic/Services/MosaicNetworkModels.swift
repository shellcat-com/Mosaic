import Foundation

struct ChallengeRecord: Codable, Sendable {
    let id: UUID
    let name: String
    let purpose: String
    let goal: Int
    let revealAt: Date
    let status: String
    let invitationCode: String
    let isShowcase: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, purpose, goal, status
        case revealAt = "reveal_at"
        case invitationCode = "invitation_code"
        case isShowcase = "is_showcase"
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
    let sandbox: ChallengeRecord
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
