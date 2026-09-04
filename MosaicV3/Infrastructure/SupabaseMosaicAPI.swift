@preconcurrency import Supabase
import Foundation

private struct MosaicCreatePayload: Encodable, Sendable {
    struct Activity: Encodable, Sendable {
        let title: String
        let purpose: String
        let sortOrder: Int
    }

    let name: String
    let communityName: String
    let description: String
    let activities: [Activity]
    let artworkID: UUID
    let filmLookID: FilmLookID
    let shotLimit: Int
    let startAt: Date
    let revealAt: Date
    let goal: Int

    init(_ draft: MosaicDraft) {
        name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        communityName = draft.communityName.trimmingCharacters(in: .whitespacesAndNewlines)
        description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        activities = draft.activities.enumerated().compactMap { index, activity in
            let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return Activity(
                title: title,
                purpose: activity.purpose.trimmingCharacters(in: .whitespacesAndNewlines),
                sortOrder: index
            )
        }
        artworkID = draft.artwork.id
        filmLookID = draft.filmLookID
        shotLimit = draft.shotLimit
        startAt = draft.startAt
        revealAt = draft.revealAt
        goal = draft.goal
    }
}

actor SupabaseMosaicAPI: MosaicAPI {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func listMosaics() async throws -> [MosaicSummary] {
        try await client.rpc("v3_list_mosaics").execute().value
    }

    func createMosaic(_ draft: MosaicDraft) async throws -> MosaicEvent {
        struct Parameters: Encodable { let payload: MosaicCreatePayload }
        return try await client.rpc(
            "v3_create_mosaic",
            params: Parameters(payload: MosaicCreatePayload(draft))
        ).execute().value
    }

    func createPremiumMosaic(_ draft: MosaicDraft, requestID: UUID) async throws -> MosaicEvent {
        struct Body: Encodable {
            let requestID: UUID
            let payload: MosaicCreatePayload
        }
        struct Response: Decodable { let mosaicID: UUID }
        let response: Response = try await client.functions.invoke(
            "create-premium-mosaic",
            options: FunctionInvokeOptions(body: Body(requestID: requestID, payload: MosaicCreatePayload(draft)))
        )
        return try await loadMosaic(response.mosaicID)
    }

    func billingSnapshot() async throws -> BillingSnapshot {
        try await client.rpc("v3_billing_snapshot").execute().value
    }

    func refreshBilling() async throws -> BillingSnapshot {
        struct EmptyBody: Encodable {}
        return try await client.functions.invoke(
            "refresh-billing",
            options: FunctionInvokeOptions(body: EmptyBody())
        )
    }

    func resolveInvitation(_ code: String) async throws -> MosaicInvitationPreview {
        struct Parameters: Encodable { let invitationCode: String }
        return try await client.rpc("v3_resolve_invitation", params: Parameters(invitationCode: normalized(code))).execute().value
    }

    func joinMosaic(_ code: String) async throws -> MosaicEvent {
        struct Parameters: Encodable { let invitationCode: String }
        let event: MosaicEvent = try await client.rpc("v3_join_mosaic", params: Parameters(invitationCode: normalized(code))).execute().value
        return try await hydratePhotos(in: event)
    }

    func loadMosaic(_ id: UUID) async throws -> MosaicEvent {
        struct Parameters: Encodable { let mosaicID: UUID }
        let event: MosaicEvent = try await client.rpc("v3_load_mosaic", params: Parameters(mosaicID: id)).execute().value
        return try await hydratePhotos(in: event)
    }

    func updateMosaic(_ id: UUID, name: String, description: String) async throws -> MosaicEvent {
        struct Parameters: Encodable { let mosaicID: UUID; let name: String; let description: String }
        return try await client.rpc("v3_update_mosaic", params: Parameters(mosaicID: id, name: name, description: description)).execute().value
    }

    func deleteMosaic(_ id: UUID) async throws {
        struct Parameters: Encodable { let mosaicID: UUID }
        let _: Bool = try await client.rpc("v3_delete_mosaic", params: Parameters(mosaicID: id)).execute().value
    }

    func completeActivity(mosaicID: UUID, activityID: UUID, note: String?) async throws -> KindnessContribution {
        struct Parameters: Encodable { let mosaicID: UUID; let activityID: UUID; let note: String? }
        return try await client.rpc("v3_complete_activity", params: Parameters(mosaicID: mosaicID, activityID: activityID, note: cleaned(note))).execute().value
    }

    func updateContribution(_ id: UUID, note: String?) async throws -> KindnessContribution {
        struct Parameters: Encodable { let contributionID: UUID; let note: String? }
        return try await client.rpc("v3_update_contribution", params: Parameters(contributionID: id, note: cleaned(note))).execute().value
    }

    func withdrawContribution(_ id: UUID) async throws {
        struct Parameters: Encodable { let contributionID: UUID }
        let _: Bool = try await client.rpc("v3_withdraw_contribution", params: Parameters(contributionID: id)).execute().value
    }

    func preparePhoto(mosaicID: UUID, photoID: UUID, byteCount: Int, pixelWidth: Int, pixelHeight: Int) async throws -> PreparedPhotoUpload {
        struct Parameters: Encodable {
            let mosaicID: UUID; let photoID: UUID; let mimeType: String
            let byteCount: Int; let pixelWidth: Int; let pixelHeight: Int
        }
        return try await client.rpc("v3_prepare_event_photo", params: Parameters(
            mosaicID: mosaicID, photoID: photoID, mimeType: "image/jpeg",
            byteCount: byteCount, pixelWidth: pixelWidth, pixelHeight: pixelHeight
        )).execute().value
    }

    func uploadPhoto(_ upload: PreparedPhotoUpload, jpeg: Data) async throws {
        try await client.storage.from("event-photos").upload(
            upload.path, data: jpeg,
            options: FileOptions(cacheControl: "31536000", contentType: "image/jpeg", upsert: false)
        )
    }

    func finalizePhoto(_ photoID: UUID) async throws -> EventPhoto {
        struct Parameters: Encodable { let photoID: UUID }
        return try await client.rpc("v3_finalize_event_photo", params: Parameters(photoID: photoID)).execute().value
    }

    func deletePhoto(_ photoID: UUID) async throws {
        struct Parameters: Encodable { let photoID: UUID }
        let path: String = try await client.rpc(
            "v3_prepare_delete_event_photo",
            params: Parameters(photoID: photoID)
        ).execute().value
        try await client.storage.from("event-photos").remove(paths: [path])
        let _: Bool = try await client.rpc("v3_delete_event_photo", params: Parameters(photoID: photoID)).execute().value
    }

    func reportPhoto(_ photoID: UUID, reason: String) async throws {
        struct Parameters: Encodable { let photoID: UUID; let reason: String }
        let _: Bool = try await client.rpc("v3_report_event_photo", params: Parameters(photoID: photoID, reason: reason)).execute().value
    }

    func blockUser(_ userID: UUID) async throws {
        struct Parameters: Encodable { let blockedID: UUID }
        let _: Bool = try await client.rpc("v3_block_user", params: Parameters(blockedID: userID)).execute().value
    }

    func unblockUser(_ userID: UUID) async throws {
        struct Parameters: Encodable { let blockedID: UUID }
        let _: Bool = try await client.rpc("v3_unblock_user", params: Parameters(blockedID: userID)).execute().value
    }

    func blockedUsers() async throws -> [BlockedUser] {
        try await client.rpc("v3_list_blocked_users").execute().value
    }

    func releaseArtwork(_ mosaicID: UUID) async throws -> ArtworkRevealMaterial? {
        struct Parameters: Encodable { let mosaicID: UUID }
        struct Release: Decodable {
            let ciphertextPath: String
            let checksum: String
            let key: String
            let nonce: String
        }
        let release: Release = try await client.rpc(
            "v3_release_artwork",
            params: Parameters(mosaicID: mosaicID)
        ).execute().value
        let ciphertext = try await client.storage.from("artwork-reveal-packages").download(path: release.ciphertextPath)
        return ArtworkRevealMaterial(
            mosaicID: mosaicID,
            ciphertext: ciphertext,
            checksum: release.checksum,
            keyBase64: release.key,
            nonceBase64: release.nonce
        )
    }

    func clearPrivateState() async {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "MosaicGallery", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
    }

    private func normalized(_ code: String) -> String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private func cleaned(_ note: String?) -> String? {
        guard let value = note?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return String(value.prefix(500))
    }

    private func hydratePhotos(in source: MosaicEvent) async throws -> MosaicEvent {
        var event = source
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "MosaicGallery", directoryHint: .isDirectory)
            .appending(path: event.id.uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pending = event.photos.indices.compactMap { index -> (Int, UUID, String)? in
            guard let path = event.photos[index].storagePath else { return nil }
            return (index, event.photos[index].id, path)
        }
        for batchStart in stride(from: 0, to: pending.count, by: 4) {
            let batch = pending[batchStart..<min(batchStart + 4, pending.count)]
            let hydrated = try await withThrowingTaskGroup(of: (Int, URL).self) { group in
                for (index, photoID, path) in batch {
                    group.addTask { [client] in
                        try Task.checkCancellation()
                        let url = directory.appending(path: "\(photoID.uuidString).jpg")
                        if !FileManager.default.fileExists(atPath: url.path()) {
                            let data = try await client.storage.from("event-photos").download(path: path)
                            try Task.checkCancellation()
                            try data.write(to: url, options: [.atomic, .completeFileProtection])
                        }
                        return (index, url)
                    }
                }
                var results: [(Int, URL)] = []
                for try await result in group { results.append(result) }
                return results
            }
            for (index, url) in hydrated { event.photos[index].localURL = url }
        }
        return event
    }
}
