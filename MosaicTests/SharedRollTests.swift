import Foundation
import Testing
@testable import Mosaic

struct SharedRollTests {
    @Test func standaloneMomentsNeverInflateVerifiedImpact() async throws {
        let participant = UUID()
        let mission = Mission(title: "Help", detail: "Help", category: .community, minutes: 5,
                              effort: "Easy", evidence: [.reflection])
        let contribution = TileContribution(
            id: UUID(), mission: mission, emotion: .hopeful, evidence: .reflection,
            contributor: "Neighbor", sharedMemory: true, isRevived: false,
            participantID: participant,
            memory: ContributionMemory(kind: .reflection, note: "A verified action", recapConsent: true, attributionAllowed: true)
        )
        let challengeID = UUID()
        let moment = SharedMoment(
            challengeID: challengeID, creatorID: UUID(), note: "A social moment",
            attribution: .anonymous, revealConsent: true, exportConsent: true, lifecycle: .approved
        )
        let challenge = KindnessChallenge(
            id: challengeID, name: "Shared Roll", purpose: "Test", goal: 10,
            revealDate: .now, revealedAt: .now, serverStatus: "revealed",
            invitationCode: "ROLL01", contributions: [contribution], sharedMoments: [moment]
        )

        let (meta, sources) = try await AppStoreRecapAdapter(challenge: challenge).loadRecap(challengeID: challengeID)
        #expect(meta.impact.acceptedActions == 1)
        #expect(meta.impact.participantCount == 1)
        #expect(sources.contains { $0.origin == .sharedMoment && $0.contributionID == nil && $0.tile == nil })
    }

    @Test func exportConsentIsSeparateAndDefaultsOff() {
        let moment = SharedMoment(challengeID: UUID(), creatorID: UUID())
        #expect(moment.revealConsent)
        #expect(!moment.exportConsent)
        #expect(moment.attribution == .anonymous)
    }

    @Test func reminderBuilderNeverCreatesMoreThanTwoRequests() {
        let summary = ChallengeSummary(
            id: UUID(), name: "Roll", groupName: "Friends", purpose: "Together",
            startAt: .now, revealAt: .now.addingTimeInterval(172_800), revealedAt: nil,
            serverStatus: "active", scheduleRevision: 1, contributionCount: 0, goal: 8,
            recapAvailability: .unavailable, recapThumbnailFilename: nil
        )
        let requests = LocalMomentReminderService.requests(for: summary, lastActivity: nil)
        #expect(requests.count == 2)
        #expect(Set(requests.map(\.identifier)).count == 2)
    }

    @Test func cameraAndRecapDeepLinksAreDistinct() {
        let id = UUID()
        #expect(EventRouteParser.parse(URL(string: "mosaic://camera/\(id)")!) == .camera(id))
        #expect(EventRouteParser.parse(URL(string: "mosaic://recap/\(id)")!) == .recap(id))
    }

    @Test func analyticsEventVocabularyContainsNoContentFields() {
        let names = Set(EngagementEventName.allCases.map(\.rawValue))
        #expect(names.contains("camera_open"))
        #expect(names.contains("recap_share"))
        #expect(!names.contains("note"))
        #expect(!names.contains("photo"))
        #expect(!names.contains("search"))
    }
}
