import Foundation

enum SharedMomentMediaKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case photo
    case video
    case note

    var id: String { rawValue }
}

struct SharedMomentPayload: Sendable {
    let kind: SharedMomentMediaKind
    let data: Data?
    let mimeType: String?
    let durationSeconds: Double?

    static func photo(_ data: Data) -> SharedMomentPayload {
        SharedMomentPayload(kind: .photo, data: data, mimeType: "image/jpeg", durationSeconds: nil)
    }

    static func video(
        _ data: Data,
        duration: Double,
        mimeType: String = "video/quicktime"
    ) -> SharedMomentPayload {
        SharedMomentPayload(kind: .video, data: data, mimeType: mimeType, durationSeconds: duration)
    }

    static var note: SharedMomentPayload {
        SharedMomentPayload(kind: .note, data: nil, mimeType: nil, durationSeconds: nil)
    }
}

struct KindnessMomentDraft: Sendable {
    let id: UUID
    let challengeID: UUID
    let creatorID: UUID
    let mission: Mission
    let payload: SharedMomentPayload
    let caption: String?
    let exportConsent: Bool

    init(
        id: UUID = UUID(), challengeID: UUID, creatorID: UUID, mission: Mission,
        payload: SharedMomentPayload, caption: String? = nil,
        exportConsent: Bool = false
    ) {
        self.id = id
        self.challengeID = challengeID
        self.creatorID = creatorID
        self.mission = mission
        self.payload = payload
        let cleaned = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.caption = cleaned?.isEmpty == false ? cleaned : nil
        self.exportConsent = exportConsent
    }
}

struct KindnessMomentReceipt: Sendable {
    let contributionID: UUID
    let tilePosition: Int
    let moment: SharedMoment
}

enum SharedMomentLifecycle: String, Codable, CaseIterable, Sendable {
    case localDraft = "local_draft"
    case uploadPending = "upload_pending"
    case sealedPendingReview = "sealed_pending_review"
    case sealed
    case approved
    case rejected
    case deleted
    case reported
    case consentRevoked = "consent_revoked"

    var isSealed: Bool {
        self == .uploadPending || self == .sealedPendingReview || self == .sealed || self == .approved
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
    let contributionID: UUID?
    let filmLookID: FilmLookID?
    var missionID: UUID?
    var editorialCategory: MissionCategory?
    var note: String?
    var localAssetName: String?
    var remoteMediaPath: String?
    var mediaKind: SharedMomentMediaKind
    var mediaMimeType: String?
    var durationSeconds: Double?
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
        contributionID: UUID? = nil, filmLookID: FilmLookID? = nil, missionID: UUID? = nil,
        editorialCategory: MissionCategory? = nil, note: String? = nil,
        localAssetName: String? = nil, remoteMediaPath: String? = nil,
        mediaKind: SharedMomentMediaKind = .note, mediaMimeType: String? = nil,
        durationSeconds: Double? = nil,
        attribution: SharedMomentAttribution = .anonymous,
        revealConsent: Bool = true, exportConsent: Bool = false,
        mediaVersion: Int = 1, consentVersion: Int = 1,
        createdAt: Date = .now, updatedAt: Date = .now,
        lifecycle: SharedMomentLifecycle = .localDraft
    ) {
        self.id = id
        self.challengeID = challengeID
        self.creatorID = creatorID
        self.contributionID = contributionID
        self.filmLookID = filmLookID
        self.missionID = missionID
        self.editorialCategory = editorialCategory
        let cleaned = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = cleaned?.isEmpty == false ? cleaned : nil
        self.localAssetName = localAssetName
        self.remoteMediaPath = remoteMediaPath
        self.mediaKind = mediaKind
        self.mediaMimeType = mediaMimeType
        self.durationSeconds = durationSeconds
        self.attribution = attribution
        self.revealConsent = revealConsent
        self.exportConsent = exportConsent
        self.mediaVersion = mediaVersion
        self.consentVersion = consentVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lifecycle = lifecycle
    }

    private enum CodingKeys: String, CodingKey {
        case id, challengeID, creatorID, contributionID, filmLookID, missionID, editorialCategory, note, localAssetName, remoteMediaPath
        case mediaKind, mediaMimeType, durationSeconds, attribution, revealConsent, exportConsent
        case mediaVersion, consentVersion, createdAt, updatedAt, lifecycle
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        challengeID = try values.decode(UUID.self, forKey: .challengeID)
        creatorID = try values.decode(UUID.self, forKey: .creatorID)
        contributionID = try values.decodeIfPresent(UUID.self, forKey: .contributionID)
        filmLookID = try values.decodeIfPresent(FilmLookID.self, forKey: .filmLookID)
        missionID = try values.decodeIfPresent(UUID.self, forKey: .missionID)
        editorialCategory = try values.decodeIfPresent(MissionCategory.self, forKey: .editorialCategory)
        note = try values.decodeIfPresent(String.self, forKey: .note)
        localAssetName = try values.decodeIfPresent(String.self, forKey: .localAssetName)
        remoteMediaPath = try values.decodeIfPresent(String.self, forKey: .remoteMediaPath)
        mediaKind = try values.decodeIfPresent(SharedMomentMediaKind.self, forKey: .mediaKind)
            ?? Self.inferMediaKind(local: localAssetName, remote: remoteMediaPath)
        mediaMimeType = try values.decodeIfPresent(String.self, forKey: .mediaMimeType)
        durationSeconds = try values.decodeIfPresent(Double.self, forKey: .durationSeconds)
        attribution = try values.decode(SharedMomentAttribution.self, forKey: .attribution)
        revealConsent = try values.decode(Bool.self, forKey: .revealConsent)
        exportConsent = try values.decode(Bool.self, forKey: .exportConsent)
        mediaVersion = try values.decode(Int.self, forKey: .mediaVersion)
        consentVersion = try values.decode(Int.self, forKey: .consentVersion)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        lifecycle = try values.decode(SharedMomentLifecycle.self, forKey: .lifecycle)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(challengeID, forKey: .challengeID)
        try values.encode(creatorID, forKey: .creatorID)
        try values.encodeIfPresent(contributionID, forKey: .contributionID)
        try values.encodeIfPresent(filmLookID, forKey: .filmLookID)
        try values.encodeIfPresent(missionID, forKey: .missionID)
        try values.encodeIfPresent(editorialCategory, forKey: .editorialCategory)
        try values.encodeIfPresent(note, forKey: .note)
        try values.encodeIfPresent(localAssetName, forKey: .localAssetName)
        try values.encodeIfPresent(remoteMediaPath, forKey: .remoteMediaPath)
        try values.encode(mediaKind, forKey: .mediaKind)
        try values.encodeIfPresent(mediaMimeType, forKey: .mediaMimeType)
        try values.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try values.encode(attribution, forKey: .attribution)
        try values.encode(revealConsent, forKey: .revealConsent)
        try values.encode(exportConsent, forKey: .exportConsent)
        try values.encode(mediaVersion, forKey: .mediaVersion)
        try values.encode(consentVersion, forKey: .consentVersion)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(updatedAt, forKey: .updatedAt)
        try values.encode(lifecycle, forKey: .lifecycle)
    }

    private static func inferMediaKind(local: String?, remote: String?) -> SharedMomentMediaKind {
        let path = (local ?? remote ?? "").lowercased()
        if path.hasSuffix(".mov") || path.hasSuffix(".mp4") { return .video }
        return path.isEmpty ? .note : .photo
    }
}

protocol SharedMomentRepository: Sendable {
    func moments(challengeID: UUID) async throws -> [SharedMoment]
    func saveDraft(_ moment: SharedMoment, payload: SharedMomentPayload) async throws -> SharedMoment
    func seal(_ moment: SharedMoment, payload: SharedMomentPayload) async throws -> SharedMoment
    func sealKindnessMoment(_ draft: KindnessMomentDraft, filmLook: FilmLookID, predictedPosition: Int) async throws -> KindnessMomentReceipt
    func moderate(momentID: UUID, approved: Bool) async throws -> SharedMoment
    func updateConsent(momentID: UUID, reveal: Bool, export: Bool) async throws -> SharedMoment
    func delete(momentID: UUID) async throws
}

protocol SharedMomentMediaStore: Sendable {
    func storeDraft(_ payload: SharedMomentPayload, id: UUID) async throws -> String
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
    case artworkPrefetchCompleted = "artwork_prefetch_completed"
    case artworkDecryptFailed = "artwork_decrypt_failed"
    case revealComplete = "reveal_complete"
    case revealSkipped = "reveal_skipped"
    case legacyFallbackUsed = "legacy_fallback_used"
}

protocol EngagementTracking: Sendable {
    func track(_ event: EngagementEventName, challengeID: UUID) async
}

struct NoopEngagementTracker: EngagementTracking {
    func track(_ event: EngagementEventName, challengeID: UUID) async {}
}
