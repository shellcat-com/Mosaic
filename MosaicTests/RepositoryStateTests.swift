import Foundation
import Testing
@testable import Mosaic

@MainActor
struct RepositoryStateTests {
    @Test func bootstrapFailureKeepsReadableDemoSnapshot() async {
        let repository = MockMosaicRepository()
        repository.bootstrapError = MockFailure.offline
        let store = AppStore(repository: repository)
        let originalChallengeID = store.challenge.id

        await store.bootstrap()

        #expect(store.challenge.id == originalChallengeID)
        guard case .cached = store.backendState else {
            Issue.record("Expected a cached read-only state")
            return
        }
        #expect(store.backendMessage != nil)
    }

    @Test func failedSubmissionRemainsRetryable() async {
        let repository = MockMosaicRepository()
        repository.submitError = MockFailure.offline
        let store = AppStore(repository: repository)
        let mission = store.missions[0]
        let contribution = TileContribution(
            id: UUID(), mission: mission, emotion: .hopeful, evidence: .reflection,
            contributor: nil, sharedMemory: false, isRevived: false, status: .selfAttested
        )

        let firstAttempt = await store.submitContribution(
            contribution,
            reflection: "Retry me",
            mediaData: nil,
            mimeType: nil,
            durationSeconds: nil,
            includeMemory: false,
            showIdentity: false,
            exportConsent: false
        )

        #expect(!firstAttempt)
        #expect(store.pendingContribution?.id == contribution.id)
        guard case .failed = store.backendState else {
            Issue.record("Expected a recoverable failed-write state")
            return
        }

        repository.submitError = nil
        let secondAttempt = await store.submitContribution(
            contribution,
            reflection: "Retry me",
            mediaData: nil,
            mimeType: nil,
            durationSeconds: nil,
            includeMemory: false,
            showIdentity: false,
            exportConsent: false
        )

        #expect(secondAttempt)
        #expect(repository.submissionCount == 2)
        #expect(store.pendingContribution?.status == .selfAttested)
    }
}

private enum MockFailure: Error {
    case offline
}

@MainActor
private final class MockMosaicRepository: MosaicRepository {
    let showcaseID = UUID()
    let sandboxID = UUID()
    var bootstrapError: Error?
    var submitError: Error?
    var submissionCount = 0

    func bootstrap(displayName: String?, privacy: String?) async throws -> DemoBootstrapResponse {
        if let bootstrapError { throw bootstrapError }
        return DemoBootstrapResponse(
            showcase: challengeRecord(id: showcaseID, code: "KIND42", showcase: true),
            sandbox: challengeRecord(id: sandboxID, code: "MOCK123", showcase: false)
        )
    }

    func join(code: String, displayName: String, privacy: String) async throws -> ChallengeRecord {
        challengeRecord(id: sandboxID, code: code, showcase: false)
    }

    func loadChallenge(id: UUID) async throws -> (KindnessChallenge, [Mission]) {
        let mission = Mission(
            title: "Mock mission", detail: "Synthetic", category: .community,
            minutes: 5, effort: "Easy", evidence: [.reflection]
        )
        return (
            KindnessChallenge(
                id: id,
                name: id == showcaseID ? "Mock Showcase" : "Mock Sandbox",
                purpose: "State tests",
                goal: 4,
                revealDate: .now.addingTimeInterval(3_600),
                invitationCode: id == showcaseID ? "KIND42" : "MOCK123",
                contributions: []
            ),
            [mission]
        )
    }

    func submit(_ draft: EvidenceDraft) async throws -> ContributionRecord {
        submissionCount += 1
        if let submitError { throw submitError }
        return ContributionRecord(
            id: draft.id,
            challengeId: draft.challengeID,
            missionId: draft.missionID,
            emotion: draft.emotion,
            evidenceMethod: draft.method,
            status: draft.method == .reflection ? .selfAttested : .pendingReview,
            verificationLevel: draft.method == .reflection ? "self_attested" : nil,
            tilePosition: nil
        )
    }

    func moderate(contributionID: UUID, evidenceApproved: Bool, memoryApproved: Bool?) async throws -> ContributionRecord {
        record(id: contributionID, status: evidenceApproved ? .verified : .rejected)
    }

    func place(contributionID: UUID) async throws -> ContributionRecord {
        record(id: contributionID, status: .placed)
    }

    func reveal(challengeID: UUID, now: Bool, at: Date?) async throws -> ChallengeRecord {
        challengeRecord(id: challengeID, code: "MOCK123", showcase: false, status: "revealed")
    }

    func changes(for challengeID: UUID) async throws -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }

    private func challengeRecord(
        id: UUID,
        code: String,
        showcase: Bool,
        status: String = "active"
    ) -> ChallengeRecord {
        ChallengeRecord(
            id: id,
            name: showcase ? "Mock Showcase" : "Mock Sandbox",
            purpose: "State tests",
            goal: 4,
            revealAt: .now.addingTimeInterval(3_600),
            status: status,
            invitationCode: code,
            isShowcase: showcase
        )
    }

    private func record(id: UUID, status: ContributionStatus) -> ContributionRecord {
        ContributionRecord(
            id: id,
            challengeId: sandboxID,
            missionId: UUID(),
            emotion: .hopeful,
            evidenceMethod: .reflection,
            status: status,
            verificationLevel: nil,
            tilePosition: status == .placed ? 0 : nil
        )
    }
}
