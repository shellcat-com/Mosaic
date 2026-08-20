import Foundation

enum SharedMomentLifecycle: String, Codable, CaseIterable, Sendable {
    case localDraft = "local_draft"
    case uploadPending = "upload_pending"
    case sealedPendingReview = "sealed_pending_review"
    case approved
    case rejected
    case deleted
    case reported
    case consentRevoked = "consent_revoked"

    var isSealed: Bool {
        self == .uploadPending || self == .sealedPendingReview || self == .approved
    }
}

enum SharedMomentAttribution: String, Codable, CaseIterable, Identifiable, Sendable {
    case anonymous
    case permitted
    var id: String { rawValue }
}

struct SharedMoment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let challengeID: UUID
    let creatorID: UUID
    var editorialCategory: MissionCategory?
    var note: String?
    var localAssetName: String?
    var remoteMediaPath: String?
    var attribution: SharedMomentAttribution
    var revealConsent: Bool
    var exportConsent: Bool
    var mediaVersion: Int
    var consentVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var lifecycle: SharedMomentLifecycle

    init(
        id: UUID = UUID(), challengeID: UUID, creatorID: UUID,
        editorialCategory: MissionCategory? = nil, note: String? = nil,
        localAssetName: String? = nil, remoteMediaPath: String? = nil,
        attribution: SharedMomentAttribution = .anonymous,
        revealConsent: Bool = true, exportConsent: Bool = false,
        mediaVersion: Int = 1, consentVersion: Int = 1,
        createdAt: Date = .now, updatedAt: Date = .now,
        lifecycle: SharedMomentLifecycle = .localDraft
    ) {
        self.id = id
        self.challengeID = challengeID
        self.creatorID = creatorID
        self.editorialCategory = editorialCategory
        let cleaned = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = cleaned?.isEmpty == false ? cleaned : nil
        self.localAssetName = localAssetName
        self.remoteMediaPath = remoteMediaPath
        self.attribution = attribution
        self.revealConsent = revealConsent
        self.exportConsent = exportConsent
        self.mediaVersion = mediaVersion
        self.consentVersion = consentVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lifecycle = lifecycle
    }
}

protocol SharedMomentRepository: Sendable {
    func moments(challengeID: UUID) async throws -> [SharedMoment]
    func saveDraft(_ moment: SharedMoment, jpegData: Data) async throws -> SharedMoment
    func seal(_ moment: SharedMoment, jpegData: Data) async throws -> SharedMoment
    func moderate(momentID: UUID, approved: Bool) async throws -> SharedMoment
    func updateConsent(momentID: UUID, reveal: Bool, export: Bool) async throws -> SharedMoment
    func delete(momentID: UUID) async throws
}

protocol SharedMomentMediaStore: Sendable {
    func storeDraft(_ jpegData: Data, id: UUID) async throws -> String
    func data(for localAssetName: String) async throws -> Data
    func remove(localAssetName: String) async
}

protocol MomentReminderService: Sendable {
    func requestAndSchedule(for challenge: ChallengeSummary, lastActivity: Date?) async -> Bool
    func cancel(challengeID: UUID) async
}

enum EngagementEventName: String, Codable, CaseIterable, Sendable {
    case cameraImpression = "camera_impression"
    case cameraOpen = "camera_open"
    case shutter
    case review
    case sealed
    case reminderOptIn = "reminder_opt_in"
    case revealOpen = "reveal_open"
    case recapOpen = "recap_open"
    case recapExport = "recap_export"
    case recapShare = "recap_share"
}

protocol EngagementTracking: Sendable {
    func track(_ event: EngagementEventName, challengeID: UUID) async
}

struct NoopEngagementTracker: EngagementTracking {
    func track(_ event: EngagementEventName, challengeID: UUID) async {}
}
