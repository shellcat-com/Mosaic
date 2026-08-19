import Foundation

@MainActor
protocol MosaicRepository: AnyObject {
    func bootstrap(displayName: String?, privacy: String?) async throws -> DemoBootstrapResponse
    func join(code: String, displayName: String, privacy: String) async throws -> ChallengeRecord
    func loadChallenge(id: UUID) async throws -> (KindnessChallenge, [Mission])
    func submit(_ draft: EvidenceDraft) async throws -> ContributionRecord
    func moderate(contributionID: UUID, evidenceApproved: Bool, memoryApproved: Bool?) async throws -> ContributionRecord
    func place(contributionID: UUID) async throws -> ContributionRecord
    func reveal(challengeID: UUID, now: Bool, at: Date?) async throws -> ChallengeRecord
    func changes(for challengeID: UUID) async throws -> AsyncStream<Void>
}
