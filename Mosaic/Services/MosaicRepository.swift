import Foundation

@MainActor
protocol MosaicRepository: AnyObject {
    func prepareDemo(displayName: String?, privacy: ParticipantPrivacy) async throws -> DemoBootstrapResponse
    func resolveInvitation(code: String) async throws -> InvitationPreview
    func join(code: String, displayName: String?, privacy: ParticipantPrivacy) async throws -> ChallengeRecord
    func configureChallenge(_ draft: ChallengeDraft, challengeID: UUID) async throws -> ChallengeRecord
    func listArtworks(collection: KinderThemeCollection?, search: String?) async throws -> ArtworkCatalogResponse
    func prefetchRevealArtwork(challengeID: UUID) async throws -> RevealArtworkPrefetch
    func getRevealedArtwork(challengeID: UUID) async throws -> RevealedArtworkResponse
    func loadChallenge(id: UUID) async throws -> (KindnessChallenge, [Mission])
    func listChallenges() async throws -> [ChallengeSummary]
    func submit(_ draft: EvidenceDraft) async throws -> ContributionRecord
    func moderate(contributionID: UUID, evidenceApproved: Bool, memoryApproved: Bool?) async throws -> ContributionRecord
    func place(contributionID: UUID) async throws -> ContributionRecord
    func reveal(challengeID: UUID, now: Bool, at: Date?) async throws -> ChallengeRecord
    func updateNotificationPreferences(challengeID: UUID, preferences: NotificationPreferences) async throws
    func registerDevice(token: String, environment: String) async throws
    func registerLiveActivityToken(token: String, challengeID: UUID, activityID: String) async throws
    func changes(for challengeID: UUID) async throws -> AsyncStream<Void>
}

extension MosaicRepository {
    func resolveInvitation(code: String) async throws -> InvitationPreview {
        throw MosaicRepositoryCapabilityError.unsupported
    }
    func configureChallenge(_ draft: ChallengeDraft, challengeID: UUID) async throws -> ChallengeRecord {
        throw MosaicRepositoryCapabilityError.unsupported
    }
    func listChallenges() async throws -> [ChallengeSummary] { [] }
    func listArtworks(collection: KinderThemeCollection?, search: String?) async throws -> ArtworkCatalogResponse {
        ArtworkCatalogResponse(enabled: false, artworks: [])
    }
    func prefetchRevealArtwork(challengeID: UUID) async throws -> RevealArtworkPrefetch {
        throw MosaicRepositoryCapabilityError.unsupported
    }
    func getRevealedArtwork(challengeID: UUID) async throws -> RevealedArtworkResponse {
        throw MosaicRepositoryCapabilityError.unsupported
    }
    func updateNotificationPreferences(challengeID: UUID, preferences: NotificationPreferences) async throws {}
    func registerDevice(token: String, environment: String) async throws {}
    func registerLiveActivityToken(token: String, challengeID: UUID, activityID: String) async throws {}
}

enum MosaicRepositoryCapabilityError: LocalizedError {
    case unsupported

    var errorDescription: String? { "This backend does not support Kinder Block creation yet." }
}
