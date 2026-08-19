import Foundation
import Supabase

@MainActor
final class SupabaseMosaicRepository: MosaicRepository {
    private let client: SupabaseClient

    init(configuration: SupabaseConfiguration) {
        client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.publishableKey)
    }

    func bootstrap(displayName: String?, privacy: String?) async throws -> DemoBootstrapResponse {
        if client.auth.currentSession == nil {
            _ = try await client.auth.signInAnonymously()
        }
        struct Body: Encodable { let displayName: String?; let privacy: String? }
        let response: DemoBootstrapResponse = try await client.functions.invoke(
            "bootstrap-demo",
            options: FunctionInvokeOptions(body: Body(displayName: displayName, privacy: privacy))
        )
        return response
    }

    func join(code: String, displayName: String, privacy: String) async throws -> ChallengeRecord {
        struct Body: Encodable { let code: String; let displayName: String; let privacy: String }
        let response: ChallengeResponse = try await client.functions.invoke(
            "join-challenge",
            options: FunctionInvokeOptions(body: Body(code: code, displayName: displayName, privacy: privacy))
        )
        return response.challenge
    }

    func loadChallenge(id: UUID) async throws -> (KindnessChallenge, [Mission]) {
        let challenge: ChallengeRecord = try await client.from("challenges")
            .select("id,name,purpose,goal,reveal_at,status,invitation_code,is_showcase")
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
        let value = KindnessChallenge(
            id: challenge.id,
            name: challenge.name,
            purpose: challenge.purpose,
            goal: challenge.goal,
            revealDate: challenge.revealAt,
            invitationCode: challenge.invitationCode,
            contributions: contributions
        )
        return (value, missions)
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
}
