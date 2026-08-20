import Foundation
import Supabase

@MainActor
final class SupabaseMosaicRepository: MosaicRepository {
    private let client: SupabaseClient

    init(configuration: SupabaseConfiguration) {
        client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.publishableKey)
    }

    init(client: SupabaseClient) {
        self.client = client
    }

    func prepareDemo(displayName: String?, privacy: ParticipantPrivacy) async throws -> DemoBootstrapResponse {
        if client.auth.currentSession == nil {
            _ = try await client.auth.signInAnonymously()
        }
        struct Body: Encodable { let displayName: String?; let privacy: String }
        let response: DemoBootstrapResponse = try await client.functions.invoke(
            "bootstrap-demo",
            options: FunctionInvokeOptions(body: Body(displayName: displayName, privacy: privacy.rawValue))
        )
        return response
    }

    func resolveInvitation(code: String) async throws -> InvitationPreview {
        struct Body: Encodable { let code: String }
        do {
            let response: InvitationPreviewResponse = try await client.functions.invoke(
                "resolve-invitation",
                options: FunctionInvokeOptions(body: Body(code: code))
            )
            return response.invitation
        } catch {
            throw Self.invitationError(from: error)
        }
    }

    func join(code: String, displayName: String?, privacy: ParticipantPrivacy) async throws -> ChallengeRecord {
        struct Body: Encodable { let code: String; let displayName: String?; let privacy: String }
        do {
            let response: ChallengeResponse = try await client.functions.invoke(
                "join-challenge",
                options: FunctionInvokeOptions(body: Body(code: code, displayName: displayName, privacy: privacy.rawValue))
            )
            return response.challenge
        } catch {
            throw Self.invitationError(from: error)
        }
    }

    private static func invitationError(from error: Error) -> Error {
        guard case FunctionsError.httpError(_, let data) = error,
              let payload = try? JSONDecoder().decode(FunctionErrorPayload.self, from: data) else {
            return error
        }
        return InvitationRepositoryError(message: payload.error)
    }

    func configureChallenge(_ draft: ChallengeDraft, challengeID: UUID) async throws -> ChallengeRecord {
        struct Body: Encodable {
            let challengeId: UUID
            let name: String
            let groupName: String
            let purpose: String
            let goal: Int
            let startAt: Date
            let revealAt: Date
            let themeId: String
            let themePaletteId: KinderThemePaletteID
            let themeSeed: Int
            let themeRevision: Int
        }
        let response: ChallengeResponse = try await client.functions.invoke(
            "configure-challenge",
            options: FunctionInvokeOptions(body: Body(
                challengeId: challengeID,
                name: draft.name,
                groupName: draft.groupName,
                purpose: draft.purpose,
                goal: draft.goal,
                startAt: draft.startDate,
                revealAt: draft.revealDate,
                themeId: draft.selection.themeID,
                themePaletteId: draft.selection.paletteID,
                themeSeed: draft.selection.seed,
                themeRevision: draft.selection.revision
            ))
        )
        return response.challenge
    }

    func loadChallenge(id: UUID) async throws -> (KindnessChallenge, [Mission]) {
        let challenge: ChallengeRecord = try await client.from("challenges")
            .select(Self.challengeColumns)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        let missionRecords: [MissionRecord] = try await client.from("missions")
            .select("id,challenge_id,title,detail,category,minutes,effort,accepted_evidence,sort_order")
            .eq("challenge_id", value: id.uuidString)
            .order("sort_order")
            .execute()
            .value
        let contributionRecords: [ContributionRecord] = try await client.from("contributions")
            .select("id,challenge_id,mission_id,emotion,evidence_method,status,verification_level,tile_position")
            .eq("challenge_id", value: id.uuidString)
            .order("created_at")
            .execute()
            .value

        let missions = missionRecords.map(\.mission)
        let missionByID = Dictionary(uniqueKeysWithValues: missions.map { ($0.id, $0) })
        let contributions = contributionRecords.compactMap { record -> TileContribution? in
            guard let mission = missionByID[record.missionId] else { return nil }
            return TileContribution(
                id: record.id,
                mission: mission,
                emotion: record.emotion,
                evidence: record.evidenceMethod,
                contributor: nil,
                sharedMemory: false,
                isRevived: false,
                status: record.status,
                tilePosition: record.tilePosition
            )
        }
        let recaps = try await recapRecords()
        let thumbnailFilename = await cachedThumbnailFilename(for: challenge, records: recaps)
        let value = KindnessChallenge(
            id: challenge.id,
            name: challenge.name,
            groupName: challenge.groupName ?? "Mosaic Community",
            purpose: challenge.purpose,
            goal: challenge.goal,
            startDate: challenge.effectiveStartAt,
            revealDate: challenge.revealAt,
            revealedAt: challenge.revealedAt,
            serverStatus: challenge.status,
            scheduleRevision: challenge.scheduleRevision ?? 1,
            recapAvailability: recapAvailability(for: challenge, records: recaps),
            recapThumbnailFilename: thumbnailFilename,
            invitationCode: challenge.invitationCode,
            contributions: contributions,
            theme: challenge.themeSelection,
            cameraRollEnabled: challenge.cameraRollEnabled ?? false
        )
        return (value, missions)
    }

    func listChallenges() async throws -> [ChallengeSummary] {
        let challenges: [ChallengeRecord] = try await client.from("challenges")
            .select(Self.challengeColumns)
            .order("reveal_at")
            .execute()
            .value
        let contributionRows: [ContributionChallengeRecord] = try await client.from("contributions")
            .select("challenge_id")
            .execute()
            .value
        let counts = Dictionary(grouping: contributionRows, by: \.challengeId).mapValues(\.count)
        let recaps = try await recapRecords()
        var thumbnailFilenames: [UUID: String] = [:]
        for challenge in challenges {
            if let filename = await cachedThumbnailFilename(for: challenge, records: recaps) {
                thumbnailFilenames[challenge.id] = filename
            }
        }
        return challenges.map { challenge in
            ChallengeSummary(
                id: challenge.id,
                name: challenge.name,
                groupName: challenge.groupName ?? "Mosaic Community",
                purpose: challenge.purpose,
                startAt: challenge.effectiveStartAt,
                revealAt: challenge.revealAt,
                revealedAt: challenge.revealedAt,
                serverStatus: challenge.status,
                scheduleRevision: challenge.scheduleRevision ?? 1,
                contributionCount: counts[challenge.id, default: 0],
                goal: challenge.goal,
                recapAvailability: recapAvailability(for: challenge, records: recaps),
                recapThumbnailFilename: thumbnailFilenames[challenge.id],
                theme: challenge.themeSelection
            )
        }
    }

    func submit(_ draft: EvidenceDraft) async throws -> ContributionRecord {
        struct PrepareBody: Encodable {
            let contributionId: UUID
            let challengeId: UUID
            let missionId: UUID
            let emotion: Emotion
            let evidenceMethod: EvidenceMethod
            let reflection: String?
            let mimeType: String?
            let fileSize: Int?
            let durationSeconds: Double?
        }
        let prepared: PrepareContributionResponse = try await client.functions.invoke(
            "prepare-contribution",
            options: FunctionInvokeOptions(body: PrepareBody(
                contributionId: draft.id,
                challengeId: draft.challengeID,
                missionId: draft.missionID,
                emotion: draft.emotion,
                evidenceMethod: draft.method,
                reflection: draft.reflection,
                mimeType: draft.mimeType,
                fileSize: draft.mediaData?.count,
                durationSeconds: draft.durationSeconds
            ))
        )

        if let upload = prepared.upload, let mediaData = draft.mediaData {
            try await client.storage.from("evidence-private").uploadToSignedURL(
                upload.path,
                token: upload.token,
                data: mediaData,
                options: FileOptions(cacheControl: "3600", contentType: draft.mimeType)
            )
        }

        struct FinalizeBody: Encodable {
            let contributionId: UUID
            let includeMemory: Bool
            let showIdentity: Bool
            let exportConsent: Bool
            let storyText: String?
        }
        let finalized: ContributionResponse = try await client.functions.invoke(
            "finalize-contribution",
            options: FunctionInvokeOptions(body: FinalizeBody(
                contributionId: draft.id,
                includeMemory: draft.includeMemory,
                showIdentity: draft.showIdentity,
                exportConsent: draft.exportConsent,
                storyText: draft.reflection
            ))
        )
        return finalized.contribution
    }

    func moderate(contributionID: UUID, evidenceApproved: Bool, memoryApproved: Bool?) async throws -> ContributionRecord {
        struct Body: Encodable {
            let contributionId: UUID
            let evidenceDecision: String
            let memoryDecision: String?
        }
        let response: ContributionResponse = try await client.functions.invoke(
            "moderate-contribution",
            options: FunctionInvokeOptions(body: Body(
                contributionId: contributionID,
                evidenceDecision: evidenceApproved ? "approved" : "rejected",
                memoryDecision: memoryApproved.map { $0 ? "approved" : "rejected" }
            ))
        )
        return response.contribution
    }

    func place(contributionID: UUID) async throws -> ContributionRecord {
        struct Body: Encodable { let contributionId: UUID }
        let response: ContributionResponse = try await client.functions.invoke(
            "place-tile",
            options: FunctionInvokeOptions(body: Body(contributionId: contributionID))
        )
        return response.contribution
    }

    func reveal(challengeID: UUID, now: Bool, at: Date?) async throws -> ChallengeRecord {
        struct Body: Encodable { let challengeId: UUID; let revealNow: Bool; let revealAt: Date? }
        let response: ChallengeResponse = try await client.functions.invoke(
            "set-reveal",
            options: FunctionInvokeOptions(body: Body(challengeId: challengeID, revealNow: now, revealAt: at))
        )
        return response.challenge
    }

    func updateNotificationPreferences(
        challengeID: UUID,
        preferences: NotificationPreferences
    ) async throws {
        struct Body: Encodable {
            let challengeId: UUID
            let challengeStart: Bool
            let revealDayBefore: Bool
            let revealHourBefore: Bool
            let revealNow: Bool
            let recapReady: Bool
            let liveActivity: Bool
        }
        let _: EmptyResponse = try await client.functions.invoke(
            "update-event-preferences",
            options: FunctionInvokeOptions(body: Body(
                challengeId: challengeID,
                challengeStart: preferences.challengeStart,
                revealDayBefore: preferences.revealDayBefore,
                revealHourBefore: preferences.revealHourBefore,
                revealNow: preferences.revealNow,
                recapReady: preferences.recapReady,
                liveActivity: preferences.liveActivity
            ))
        )
    }

    func registerDevice(token: String, environment: String) async throws {
        struct Body: Encodable { let token: String; let environment: String }
        let _: EmptyResponse = try await client.functions.invoke(
            "register-notification-token",
            options: FunctionInvokeOptions(body: Body(token: token, environment: environment))
        )
    }

    func registerLiveActivityToken(token: String, challengeID: UUID, activityID: String) async throws {
        struct Body: Encodable {
            let token: String
            let challengeId: UUID
            let activityId: String
            let environment: String
        }
#if DEBUG
        let environment = "sandbox"
#else
        let environment = "production"
#endif
        let _: EmptyResponse = try await client.functions.invoke(
            "register-notification-token",
            options: FunctionInvokeOptions(body: Body(
                token: token,
                challengeId: challengeID,
                activityId: activityID,
                environment: environment
            ))
        )
    }

    func changes(for challengeID: UUID) async throws -> AsyncStream<Void> {
        let channel = client.channel("challenge:\(challengeID.uuidString.lowercased())") { config in
            config.isPrivate = true
        }
        let broadcasts = channel.broadcastStream(event: "changed")
        try await channel.subscribeWithError()
        return AsyncStream { continuation in
            let task = Task {
                for await _ in broadcasts { continuation.yield(()) }
                continuation.finish()
            }
            continuation.onTermination = { [client] _ in
                task.cancel()
                Task { await client.removeChannel(channel) }
            }
        }
    }

    private func recapRecords() async throws -> [RecapListRecord] {
        try await client.from("recap_exports")
            .select("id,challenge_id,status,thumbnail_path")
            .eq("visibility", value: "challenge")
            .execute()
            .value
    }

    private func recapAvailability(
        for challenge: ChallengeRecord,
        records: [RecapListRecord]
    ) -> RecapAvailability {
        guard let featuredID = challenge.featuredRecapExportId,
              let recap = records.first(where: { $0.id == featuredID })
        else { return challenge.status == "revealed" ? .processing : .unavailable }
        return recap.status == "completed_uploaded" ? .ready : .processing
    }

    private func recapThumbnailFilename(
        for challenge: ChallengeRecord,
        records: [RecapListRecord]
    ) -> String? {
        guard let featuredID = challenge.featuredRecapExportId else { return nil }
        return records.first(where: { $0.id == featuredID })?.thumbnailPath
    }

    private func cachedThumbnailFilename(
        for challenge: ChallengeRecord,
        records: [RecapListRecord]
    ) async -> String? {
        guard let remotePath = recapThumbnailFilename(for: challenge, records: records) else { return nil }
        let remoteName = URL(fileURLWithPath: remotePath).lastPathComponent
        let filename = "recap-\(remoteName)"
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: MosaicEventCache.appGroupIdentifier
        ), FileManager.default.fileExists(atPath: container.appendingPathComponent(filename).path) {
            return filename
        }
        do {
            let data = try await client.storage.from("recap-exports").download(path: remotePath)
            return try MosaicEventCache.storeThumbnail(data, remotePath: remotePath)
        } catch {
            return nil
        }
    }

    private static let challengeColumns = "id,name,group_name,purpose,goal,start_at,reveal_at,revealed_at,status,schedule_revision,featured_recap_export_id,invitation_code,is_showcase,camera_roll_enabled,theme_id,theme_palette_id,theme_seed,theme_revision"
}

private struct FunctionErrorPayload: Decodable {
    let error: String
}

private struct InvitationRepositoryError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct EmptyResponse: Decodable, Sendable {
    let ok: Bool?
}
