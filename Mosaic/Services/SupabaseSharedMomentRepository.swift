import Foundation
import Supabase

actor SupabaseSharedMomentRepository: SharedMomentRepository, EngagementTracking {
    private let client: SupabaseClient
    private let mediaStore: SharedMomentMediaStore
    private let drafts: LocalSharedMomentRepository

    init(configuration: SupabaseConfiguration, mediaStore: SharedMomentMediaStore = ProtectedSharedMomentStore.shared) {
        client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.publishableKey)
        self.mediaStore = mediaStore
        self.drafts = LocalSharedMomentRepository(mediaStore: mediaStore)
    }

    init(client: SupabaseClient, mediaStore: SharedMomentMediaStore = ProtectedSharedMomentStore.shared) {
        self.client = client
        self.mediaStore = mediaStore
        self.drafts = LocalSharedMomentRepository(mediaStore: mediaStore)
    }

    func moments(challengeID: UUID) async throws -> [SharedMoment] {
        try await ensureSession()
        let rows: [Row] = try await client.from("shared_moments")
            .select().eq("challenge_id", value: challengeID.uuidString).order("created_at").execute().value
        let remote = rows.map(\.moment)
        let local = (try? await drafts.moments(challengeID: challengeID)) ?? []
        return remote + local.filter { draft in !remote.contains(where: { $0.id == draft.id }) }
    }

    func saveDraft(_ moment: SharedMoment, jpegData: Data) async throws -> SharedMoment {
        try await drafts.saveDraft(moment, jpegData: jpegData)
    }

    func seal(_ moment: SharedMoment, jpegData: Data) async throws -> SharedMoment {
        let localName: String
        if let existingName = moment.localAssetName {
            localName = existingName
        } else {
            localName = try await mediaStore.storeDraft(jpegData, id: moment.id)
        }
        let sanitizedData = (try? await mediaStore.data(for: localName)) ?? jpegData
        do { try await ensureSession() } catch {
            var offline = moment
            offline.localAssetName = localName
            offline.lifecycle = .uploadPending
            return (try? await drafts.saveDraft(offline, jpegData: jpegData)) ?? offline
        }
        guard let userID = client.auth.currentSession?.user.id else {
            var offline = moment; offline.localAssetName = localName; offline.lifecycle = .uploadPending
            return (try? await drafts.saveDraft(offline, jpegData: jpegData)) ?? offline
        }
        let path = "moments/\(moment.challengeID.uuidString.lowercased())/\(userID.uuidString.lowercased())/\(moment.id.uuidString.lowercased()).jpg"
        var pending = SharedMoment(
            id: moment.id, challengeID: moment.challengeID, creatorID: userID,
            editorialCategory: moment.editorialCategory, note: moment.note,
            localAssetName: localName, remoteMediaPath: path, attribution: moment.attribution,
            revealConsent: moment.revealConsent, exportConsent: moment.exportConsent,
            mediaVersion: moment.mediaVersion, consentVersion: moment.consentVersion,
            createdAt: moment.createdAt, updatedAt: .now, lifecycle: .uploadPending
        )
        let upsert = WriteRow(moment: pending, creatorID: userID)
        do {
            try await client.from("shared_moments").upsert(upsert, onConflict: "id").execute()
            try await client.storage.from("recap-memories").upload(
                path, data: sanitizedData,
                options: FileOptions(cacheControl: "31536000", contentType: "image/jpeg", upsert: true)
            )
            struct Sealed: Encodable { let lifecycle = "sealed_pending_review"; let mediaPath: String
                enum CodingKeys: String, CodingKey { case lifecycle; case mediaPath = "media_path" }
            }
            try await client.from("shared_moments").update(Sealed(mediaPath: path))
                .eq("id", value: moment.id.uuidString).execute()
            pending.lifecycle = .sealedPendingReview
        } catch {
            // The protected file and idempotent row are the offline queue. Re-entering seal retries the same path.
            pending.lifecycle = .uploadPending
            pending = (try? await drafts.saveDraft(pending, jpegData: jpegData)) ?? pending
        }
        return pending
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
        struct Deleted: Encodable { let lifecycle = "deleted"; let deletedAt = Date()
            enum CodingKeys: String, CodingKey { case lifecycle; case deletedAt = "deleted_at" }
        }
        try await client.from("shared_moments").update(Deleted()).eq("id", value: momentID.uuidString).execute()
    }

    func track(_ event: EngagementEventName, challengeID: UUID) async {
        guard (try? await ensureSession()) != nil, let actorID = client.auth.currentSession?.user.id else { return }
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

    private func ensureSession() async throws {
        if client.auth.currentSession == nil { _ = try await client.auth.signInAnonymously() }
    }
}

private struct WriteRow: Encodable {
    let id: UUID; let challengeId: UUID; let creatorId: UUID; let editorialCategory: String?; let note: String?
    let attribution: String; let revealConsent: Bool; let exportConsent: Bool; let mediaVersion: Int
    let consentVersion: Int; let lifecycle: String; let mediaPath: String?

    init(moment: SharedMoment, creatorID: UUID) {
        id = moment.id; challengeId = moment.challengeID; creatorId = creatorID
        editorialCategory = moment.editorialCategory?.rawValue; note = moment.note; attribution = moment.attribution.rawValue
        revealConsent = moment.revealConsent; exportConsent = moment.exportConsent; mediaVersion = moment.mediaVersion
        consentVersion = moment.consentVersion; lifecycle = moment.lifecycle.rawValue; mediaPath = moment.remoteMediaPath
    }
    enum CodingKeys: String, CodingKey {
        case id, note, attribution, lifecycle
        case challengeId = "challenge_id"; case creatorId = "creator_id"; case editorialCategory = "editorial_category"
        case revealConsent = "reveal_consent"; case exportConsent = "export_consent"; case mediaVersion = "media_version"
        case consentVersion = "consent_version"; case mediaPath = "media_path"
    }
}

private struct Row: Decodable {
    let id: UUID; let challengeId: UUID; let creatorId: UUID; let editorialCategory: MissionCategory?; let note: String?
    let mediaPath: String?; let attribution: SharedMomentAttribution; let revealConsent: Bool; let exportConsent: Bool
    let mediaVersion: Int; let consentVersion: Int; let createdAt: Date; let updatedAt: Date
    let lifecycle: SharedMomentLifecycle
    enum CodingKeys: String, CodingKey {
        case id, note, attribution, lifecycle
        case challengeId = "challenge_id"; case creatorId = "creator_id"; case editorialCategory = "editorial_category"
        case mediaPath = "media_path"; case revealConsent = "reveal_consent"; case exportConsent = "export_consent"
        case mediaVersion = "media_version"; case consentVersion = "consent_version"
        case createdAt = "created_at"; case updatedAt = "updated_at"
    }
    var moment: SharedMoment {
        SharedMoment(id: id, challengeID: challengeId, creatorID: creatorId, editorialCategory: editorialCategory,
                     note: note, remoteMediaPath: mediaPath, attribution: attribution, revealConsent: revealConsent,
                     exportConsent: exportConsent, mediaVersion: mediaVersion, consentVersion: consentVersion,
                     createdAt: createdAt, updatedAt: updatedAt, lifecycle: lifecycle)
    }
}
