import Foundation
import Testing
@testable import Mosaic

@MainActor
struct RepositoryStateTests {
    @Test func bootstrapDoesNotProvisionDemoAndShowsIntroWithoutMembership() async throws {
        let repository = MockMosaicRepository()
        let suite = "MosaicTests.Entry.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(repository: repository, onboardingDefaults: defaults)

        await store.bootstrap()

        #expect(repository.demoPreparationCount == 0)
        #expect(store.entryState == .intro)
        #expect(store.challengeLibrary.isEmpty)
    }

    @Test func restoredMembershipSkipsOnboardingAndOpensMainApp() async throws {
        let repository = MockMosaicRepository()
        repository.challengeSummaries = [repository.summary(id: repository.sandboxID)]
        let store = AppStore(repository: repository)

        await store.bootstrap()

        #expect(store.entryState == .main)
        #expect(store.challenge.id == repository.sandboxID)
        #expect(repository.demoPreparationCount == 0)
    }

    @Test func restoredDemoPrefersWritableSandboxOverActiveShowcase() async {
        let repository = MockMosaicRepository()
        repository.challengeSummaries = [
            repository.summary(id: repository.showcaseID, showcase: true),
            repository.summary(id: repository.sandboxID)
        ]
        let store = AppStore(repository: repository)

        await store.bootstrap()

        #expect(store.challenge.id == repository.sandboxID)
        #expect(!store.challenge.isShowcase)
    }

    @Test func joiningWaitsForConfirmationAndKeepsFailuresOnJoinScreen() async {
        let repository = MockMosaicRepository()
        repository.joinError = MockFailure.offline
        let store = AppStore(repository: repository)
        let preview = repository.preview(code: " KIND42 ")

        let joined = await store.joinInvitation(preview, name: " Maya ", privacy: .firstName)

        #expect(!joined)
        #expect(store.entryState == .joining(preview))
        #expect(repository.joinCount == 1)
        #expect(repository.lastJoinName == "Maya")
        #expect(repository.lastJoinPrivacy == .firstName)
    }

    @Test func confirmedAnonymousJoinLoadsChallengeBeforeEnteringMainApp() async {
        let repository = MockMosaicRepository()
        let store = AppStore(repository: repository)
        let preview = repository.preview(code: "KIND42")

        let joined = await store.joinInvitation(preview, name: "Ignored", privacy: .anonymous)

        #expect(joined)
        #expect(store.entryState == .main)
        #expect(store.challenge.id == repository.sandboxID)
        #expect(store.displayName.isEmpty)
        #expect(repository.lastJoinName == nil)
        #expect(repository.lastJoinPrivacy == .anonymous)
    }

    @Test func firstNamePrivacyRejectsWhitespaceOnlyNamesWithoutCallingServer() async {
        let repository = MockMosaicRepository()
        let store = AppStore(repository: repository)
        let preview = repository.preview(code: "KIND42")

        let joined = await store.joinInvitation(preview, name: "   \n", privacy: .firstName)

        #expect(!joined)
        #expect(repository.joinCount == 0)
        #expect(store.entryState != .main)
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

    @Test func readOnlyShowcaseNeverCallsSubmissionEndpoint() async {
        let repository = MockMosaicRepository()
        let store = AppStore(repository: repository)
        await store.openChallenge(repository.showcaseID)
        let mission = store.missions[0]
        let contribution = TileContribution(
            id: UUID(), mission: mission, emotion: .hopeful, evidence: .reflection,
            contributor: nil, sharedMemory: false, isRevived: false, status: .selfAttested
        )

        let succeeded = await store.submitContribution(
            contribution,
            reflection: "Must remain local",
            mediaData: nil,
            mimeType: nil,
            durationSeconds: nil,
            includeMemory: false,
            showIdentity: false,
            exportConsent: false
        )

        #expect(!succeeded)
        #expect(repository.submissionCount == 0)
        #expect(store.backendMessage == "This showcase is read-only. Open your private sandbox to create a tile.")
    }
}

private enum MockFailure: Error {
    case offline
}

@MainActor
private final class MockMosaicRepository: MosaicRepository {
    let showcaseID = UUID()
    let sandboxID = UUID()
    var demoPreparationCount = 0
    var challengeSummaries: [ChallengeSummary] = []
    var joinError: Error?
    var joinCount = 0
    var lastJoinName: String?
    var lastJoinPrivacy: ParticipantPrivacy?
    var submitError: Error?
    var submissionCount = 0

    func prepareDemo(displayName: String?, privacy: ParticipantPrivacy) async throws -> DemoBootstrapResponse {
        demoPreparationCount += 1
        return DemoBootstrapResponse(
            showcase: challengeRecord(id: showcaseID, code: "KIND42", showcase: true),
            sandbox: challengeRecord(id: sandboxID, code: "MOCK123", showcase: false)
        )
    }

    func resolveInvitation(code: String) async throws -> InvitationPreview {
        preview(code: code)
    }

    func preview(code: String) -> InvitationPreview {
        InvitationPreview(
            challengeID: sandboxID,
            code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: "Mock Sandbox",
            groupName: "Mock Group",
            purpose: "State tests",
            goal: 4,
            startAt: .now,
            revealAt: .now.addingTimeInterval(3_600),
            status: "active"
        )
    }

    func join(code: String, displayName: String?, privacy: ParticipantPrivacy) async throws -> ChallengeRecord {
        joinCount += 1
        lastJoinName = displayName
        lastJoinPrivacy = privacy
        if let joinError { throw joinError }
        return challengeRecord(id: sandboxID, code: code, showcase: false)
    }

    func listChallenges() async throws -> [ChallengeSummary] { challengeSummaries }

    func summary(id: UUID, showcase: Bool = false) -> ChallengeSummary {
        ChallengeSummary(
            id: id,
            name: showcase ? "Mock Showcase" : "Mock Sandbox",
            groupName: "Mock Group",
            purpose: "State tests",
            startAt: .now.addingTimeInterval(-60),
            revealAt: .now.addingTimeInterval(3_600),
            revealedAt: nil,
            serverStatus: "active",
            scheduleRevision: 1,
            contributionCount: 0,
            goal: 4,
            recapAvailability: .unavailable,
            recapThumbnailFilename: nil,
            isShowcase: showcase
        )
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
                isShowcase: id == showcaseID,
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
