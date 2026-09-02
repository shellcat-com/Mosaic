import Foundation
import Supabase

actor SupabaseSharedMomentRepository: SharedMomentRepository, EngagementTracking {
    private let client: SupabaseClient
    private let mediaStore: SharedMomentMediaStore
    private let drafts: LocalSharedMomentRepository

    init(configuration: SupabaseConfiguration, mediaStore: SharedMomentMediaStore = ProtectedSharedMomentStore.shared) {
        client = MosaicSupabaseClientFactory.make(configuration: configuration)
        self.mediaStore = mediaStore
        self.drafts = LocalSharedMomentRepository(mediaStore: mediaStore)
    }

    init(client: SupabaseClient, mediaStore: SharedMomentMediaStore = ProtectedSharedMomentStore.shared) {
        self.client = client
        self.mediaStore = mediaStore
        self.drafts = LocalSharedMomentRepository(mediaStore: mediaStore)
    }

    func moments(challengeID: UUID) async throws -> [SharedMoment] {
        _ = try await ensureSession()
        let rows: [Row] = try await client.from("shared_moments")
            .select().eq("challenge_id", value: challengeID.uuidString).order("created_at").execute().value
        let remote = rows.map(\.moment)
        let local = (try? await drafts.moments(challengeID: challengeID)) ?? []
        return remote + local.filter { draft in !remote.contains(where: { $0.id == draft.id }) }
    }

    func saveDraft(_ moment: SharedMoment, payload: SharedMomentPayload) async throws -> SharedMoment {
        try await drafts.saveDraft(moment, payload: payload)
    }

    func seal(_ moment: SharedMoment, payload: SharedMomentPayload) async throws -> SharedMoment {
        let localName: String?
        if let existingName = moment.localAssetName {
            localName = existingName
        } else if payload.data != nil {
            localName = try await mediaStore.storeDraft(payload, id: moment.id)
        } else {
            localName = nil
        }
        let storedData: Data?
        if let localName {
            storedData = try? await mediaStore.data(for: localName)
        } else {
            storedData = nil
        }
        let uploadData = storedData ?? payload.data
        var prepared = moment
        prepared.localAssetName = localName
        prepared.mediaKind = payload.kind
        prepared.mediaMimeType = payload.mimeType
        prepared.durationSeconds = payload.durationSeconds
        let session: Session
        do { session = try await ensureSession() } catch {
            var offline = prepared
            offline.lifecycle = .uploadPending
            return (try? await drafts.saveDraft(offline, payload: payload)) ?? offline
        }
        let userID = session.user.id
        let fileExtension = payload.kind == .video
            ? (payload.mimeType == "video/mp4" ? "mp4" : "mov")
            : "jpg"
        let path = localName == nil ? nil : "moments/\(moment.challengeID.uuidString.lowercased())/\(userID.uuidString.lowercased())/\(moment.id.uuidString.lowercased()).\(fileExtension)"
        var pending = SharedMoment(
            id: moment.id, challengeID: moment.challengeID, creatorID: userID,
            contributionID: moment.contributionID, filmLookID: moment.filmLookID, missionID: moment.missionID,
            editorialCategory: moment.editorialCategory, note: moment.note,
            localAssetName: localName, remoteMediaPath: path,
            mediaKind: payload.kind, mediaMimeType: payload.mimeType, durationSeconds: payload.durationSeconds,
            attribution: moment.attribution,
            revealConsent: moment.revealConsent, exportConsent: moment.exportConsent,
            mediaVersion: moment.mediaVersion, consentVersion: moment.consentVersion,
            createdAt: moment.createdAt, updatedAt: .now, lifecycle: .uploadPending
        )
        let upsert = WriteRow(moment: pending, creatorID: userID)
        do {
            try await client.from("shared_moments").upsert(upsert, onConflict: "id").execute()
            if let path, let uploadData {
                try await client.storage.from("recap-memories").upload(
                    path, data: uploadData,
                    options: FileOptions(cacheControl: "31536000", contentType: payload.mimeType ?? "application/octet-stream", upsert: true)
                )
            }
            struct Sealed: Encodable { let lifecycle = "sealed_pending_review"; let mediaPath: String?
                enum CodingKeys: String, CodingKey { case lifecycle; case mediaPath = "media_path" }
            }
            try await client.from("shared_moments").update(Sealed(mediaPath: path))
                .eq("id", value: moment.id.uuidString).execute()
            pending.lifecycle = .sealedPendingReview
        } catch {
            // The protected file and idempotent row are the offline queue. Re-entering seal retries the same path.
            pending.lifecycle = .uploadPending
            pending = (try? await drafts.saveDraft(pending, payload: payload)) ?? pending
        }
        return pending
    }

    func sealKindnessMoment(
        _ draft: KindnessMomentDraft,
        filmLook: FilmLookID,
        predictedPosition: Int
    ) async throws -> KindnessMomentReceipt {
        let localName: String?
        if draft.payload.data != nil {
            localName = try await mediaStore.storeDraft(draft.payload, id: draft.id)
        } else {
            localName = nil
        }
        let uploadData = if let localName {
            try? await mediaStore.data(for: localName)
        } else {
            draft.payload.data
        }

        do {
            _ = try await ensureSession()
            struct PrepareBody: Encodable {
                let contributionId: UUID
                let challengeId: UUID
                let missionId: UUID
                let mediaKind: SharedMomentMediaKind
                let mimeType: String?
                let fileSize: Int?
                let durationSeconds: Double?
                let caption: String?
                let exportConsent: Bool
            }
            let prepared: KindnessPrepareResponse = try await client.functions.invoke(
                "prepare-kindness-moment",
                options: FunctionInvokeOptions(body: PrepareBody(
                    contributionId: draft.id,
                    challengeId: draft.challengeID,
                    missionId: draft.mission.id,
                    mediaKind: draft.payload.kind,
                    mimeType: draft.payload.mimeType,
                    fileSize: uploadData?.count,
                    durationSeconds: draft.payload.durationSeconds,
                    caption: draft.caption,
                    exportConsent: draft.exportConsent
                ))
            )
            if let upload = prepared.upload, let uploadData {
                try await client.storage.from("recap-memories").uploadToSignedURL(
                    upload.path,
                    token: upload.token,
                    data: uploadData,
                    options: FileOptions(
                        cacheControl: "31536000",
                        contentType: draft.payload.mimeType ?? "application/octet-stream"
                    )
                )
            }
            struct FinalizeBody: Encodable { let contributionId: UUID }
            let finalized: KindnessFinalizeResponse = try await client.functions.invoke(
                "finalize-kindness-moment",
                options: FunctionInvokeOptions(body: FinalizeBody(contributionId: prepared.contributionId))
            )
            var moment = finalized.moment.moment
            moment.localAssetName = localName
            moment.missionID = draft.mission.id
            return KindnessMomentReceipt(
                contributionID: finalized.contributionId,
                tilePosition: finalized.tilePosition,
                moment: moment
            )
        } catch {
            let pending = SharedMoment(
                id: draft.id,
                challengeID: draft.challengeID,
                creatorID: draft.creatorID,
                contributionID: draft.id,
                filmLookID: filmLook,
                missionID: draft.mission.id,
                editorialCategory: draft.mission.category,
                note: draft.caption,
                localAssetName: localName,
                mediaKind: draft.payload.kind,
                mediaMimeType: draft.payload.mimeType,
                durationSeconds: draft.payload.durationSeconds,
                revealConsent: true,
                exportConsent: draft.exportConsent,
                lifecycle: .uploadPending
            )
            _ = try? await drafts.saveDraft(pending, payload: draft.payload)
            throw error
        }
    }

    func updateConsent(momentID: UUID, reveal: Bool, export: Bool) async throws -> SharedMoment {
        struct Consent: Encodable {
            let revealConsent: Bool; let exportConsent: Bool; let lifecycle: String
            enum CodingKeys: String, CodingKey { case revealConsent = "reveal_consent"; case exportConsent = "export_consent"; case lifecycle }
        }
        let row: Row = try await client.from("shared_moments")
            .update(Consent(revealConsent: reveal, exportConsent: export, lifecycle: reveal ? "approved" : "consent_revoked"))
            .eq("id", value: momentID.uuidString).select().single().execute().value
        return row.moment
    }

    func moderate(momentID: UUID, approved: Bool) async throws -> SharedMoment {
        struct Decision: Encodable { let lifecycle: String }
        let row: Row = try await client.from("shared_moments")
            .update(Decision(lifecycle: approved ? "approved" : "rejected"))
            .eq("id", value: momentID.uuidString).select().single().execute().value
        return row.moment
    }

    func delete(momentID: UUID) async throws {
        let row: Row? = try? await client.from("shared_moments")
            .select().eq("id", value: momentID.uuidString).single().execute().value
        if row?.contributionId != nil {
            struct Body: Encodable { let momentId: UUID }
            struct Response: Decodable { let action: String }
            let _: Response = try await client.functions.invoke(
                "withdraw-kindness-moment",
                options: FunctionInvokeOptions(body: Body(momentId: momentID))
            )
            return
        }
        struct Deleted: Encodable { let lifecycle = "deleted"; let deletedAt = Date()
            enum CodingKeys: String, CodingKey { case lifecycle; case deletedAt = "deleted_at" }
        }
        try await client.from("shared_moments").update(Deleted()).eq("id", value: momentID.uuidString).execute()
    }

    func track(_ event: EngagementEventName, challengeID: UUID) async {
        guard let actorID = try? await ensureSession().user.id else { return }
        struct Event: Encodable {
            let actorId: UUID; let challengeId: UUID; let clientEventId: UUID; let name: String
            enum CodingKeys: String, CodingKey {
                case name; case actorId = "actor_id"; case challengeId = "challenge_id"; case clientEventId = "client_event_id"
            }
        }
        _ = try? await client.from("engagement_events").insert(Event(
            actorId: actorID, challengeId: challengeID, clientEventId: UUID(), name: event.rawValue
        )).execute()
    }

    private func ensureSession() async throws -> Session {
        try await client.restoreOrCreateMosaicSession()
    }
}

private struct KindnessPrepareResponse: Decodable {
    let contributionId: UUID
    let upload: PrepareContributionResponse.Upload?
}

private struct KindnessFinalizeResponse: Decodable {
    let contributionId: UUID
    let tilePosition: Int
    let moment: Row
}

private struct WriteRow: Encodable {
    let id: UUID; let challengeId: UUID; let creatorId: UUID; let editorialCategory: String?; let note: String?
    let contributionId: UUID?; let filmLookId: FilmLookID?
    let attribution: String; let revealConsent: Bool; let exportConsent: Bool; let mediaVersion: Int
    let consentVersion: Int; let lifecycle: String; let mediaPath: String?; let mediaKind: String
    let mediaMimeType: String?; let durationSeconds: Double?

    init(moment: SharedMoment, creatorID: UUID) {
        id = moment.id; challengeId = moment.challengeID; creatorId = creatorID
        contributionId = moment.contributionID; filmLookId = moment.filmLookID
        editorialCategory = moment.editorialCategory?.rawValue; note = moment.note; attribution = moment.attribution.rawValue
        revealConsent = moment.revealConsent; exportConsent = moment.exportConsent; mediaVersion = moment.mediaVersion
        consentVersion = moment.consentVersion; lifecycle = moment.lifecycle.rawValue; mediaPath = moment.remoteMediaPath
        mediaKind = moment.mediaKind.rawValue; mediaMimeType = moment.mediaMimeType; durationSeconds = moment.durationSeconds
    }
    enum CodingKeys: String, CodingKey {
        case id, note, attribution, lifecycle
        case challengeId = "challenge_id"; case creatorId = "creator_id"; case editorialCategory = "editorial_category"
        case contributionId = "contribution_id"; case filmLookId = "film_look_id"
        case revealConsent = "reveal_consent"; case exportConsent = "export_consent"; case mediaVersion = "media_version"
        case consentVersion = "consent_version"; case mediaPath = "media_path"; case mediaKind = "media_kind"
        case mediaMimeType = "media_mime_type"; case durationSeconds = "duration_seconds"
    }
}

private struct Row: Decodable {
    let id: UUID; let challengeId: UUID; let creatorId: UUID; let editorialCategory: MissionCategory?; let note: String?
    let contributionId: UUID?; let filmLookId: FilmLookID?
    let mediaPath: String?; let attribution: SharedMomentAttribution; let revealConsent: Bool; let exportConsent: Bool
    let mediaVersion: Int; let consentVersion: Int; let createdAt: Date; let updatedAt: Date
    let lifecycle: SharedMomentLifecycle; let mediaKind: SharedMomentMediaKind?; let mediaMimeType: String?
    let durationSeconds: Double?
    enum CodingKeys: String, CodingKey {
        case id, note, attribution, lifecycle
        case challengeId = "challenge_id"; case creatorId = "creator_id"; case editorialCategory = "editorial_category"
        case contributionId = "contribution_id"; case filmLookId = "film_look_id"
        case mediaPath = "media_path"; case revealConsent = "reveal_consent"; case exportConsent = "export_consent"
        case mediaVersion = "media_version"; case consentVersion = "consent_version"
        case mediaKind = "media_kind"; case mediaMimeType = "media_mime_type"; case durationSeconds = "duration_seconds"
        case createdAt = "created_at"; case updatedAt = "updated_at"
    }
    var moment: SharedMoment {
        SharedMoment(id: id, challengeID: challengeId, creatorID: creatorId,
                     contributionID: contributionId, filmLookID: filmLookId, editorialCategory: editorialCategory,
                     note: note, remoteMediaPath: mediaPath,
                     mediaKind: mediaKind ?? inferredMediaKind, mediaMimeType: mediaMimeType,
                     durationSeconds: durationSeconds, attribution: attribution, revealConsent: revealConsent,
                     exportConsent: exportConsent, mediaVersion: mediaVersion, consentVersion: consentVersion,
                     createdAt: createdAt, updatedAt: updatedAt, lifecycle: lifecycle)
    }

    private var inferredMediaKind: SharedMomentMediaKind {
        guard let mediaPath else { return .note }
        return mediaPath.lowercased().hasSuffix(".mov") || mediaPath.lowercased().hasSuffix(".mp4") ? .video : .photo
    }
}
