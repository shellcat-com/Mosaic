import Foundation
import Testing
@testable import Mosaic

struct SharedRollTests {
    @Test @MainActor func navigationKeepsThreeStableTabsWhilePresentingDestinations() {
        let router = MosaicRouter()
        let challengeID = UUID()

        router.select(.camera)
        router.showMemoryComposer(for: challengeID)
        #expect(router.selection == .camera)
        #expect(router.cover?.id == "memory-\(challengeID.uuidString)")

        router.showRecap(for: challengeID)
        #expect(router.selection == .camera)
        #expect(router.cover?.id == "recap-\(challengeID.uuidString)")
        #expect(AppTab.allCases.map(\.rawValue) == ["Groups", "Camera", "You"])
    }

    @Test func kindnessRollSealsOneLinkedMomentAtOnePosition() async throws {
        let mission = Mission(
            title: "Leave a note", detail: "Encourage someone", category: .encouragement,
            minutes: 5, effort: "Easy", evidence: [.reflection]
        )
        let draft = KindnessMomentDraft(
            challengeID: UUID(), creatorID: UUID(), mission: mission,
            payload: .note, caption: "You made today lighter.", exportConsent: true
        )
        let repository = LocalSharedMomentRepository()
        let receipt = try await repository.sealKindnessMoment(
            draft, filmLook: .garden, predictedPosition: 4
        )

        #expect(receipt.contributionID == draft.id)
        #expect(receipt.tilePosition == 4)
        #expect(receipt.moment.contributionID == draft.id)
        #expect(receipt.moment.filmLookID == .garden)
        #expect(receipt.moment.lifecycle == .sealed)
        #expect(receipt.moment.mediaKind == .note)
    }

    @Test func photoVideoAndNoteMemoriesReachTheRecapWithoutCreatingTiles() async throws {
        let challengeID = UUID()
        let creatorID = UUID()
        let moments = [
            SharedMoment(
                challengeID: challengeID, creatorID: creatorID, note: "A photo memory",
                remoteMediaPath: "moments/photo.jpg", mediaKind: .photo, mediaMimeType: "image/jpeg",
                revealConsent: true, exportConsent: true, lifecycle: .approved
            ),
            SharedMoment(
                challengeID: challengeID, creatorID: creatorID, note: "A moving memory",
                remoteMediaPath: "moments/video.mov", mediaKind: .video, mediaMimeType: "video/quicktime",
                durationSeconds: 4.5, revealConsent: true, exportConsent: true, lifecycle: .approved
            ),
            SharedMoment(
                challengeID: challengeID, creatorID: creatorID, note: "A note-only memory",
                mediaKind: .note, revealConsent: true, exportConsent: true, lifecycle: .approved
            )
        ]
        let challenge = KindnessChallenge(
            id: challengeID, name: "Three ways to remember", purpose: "Test", goal: 8,
            revealDate: .now, revealedAt: .now, serverStatus: "revealed",
            invitationCode: "MEM123", contributions: [], sharedMoments: moments
        )

        let (meta, sources) = try await AppStoreRecapAdapter(challenge: challenge).loadRecap(challengeID: challengeID)
        #expect(meta.impact.acceptedActions == 0)
        #expect(sources.count == 3)
        #expect(sources.allSatisfy { $0.origin == .sharedMoment && $0.tile == nil && $0.contributionID == nil })
        #expect(sources.contains { if case .photo = $0.content { true } else { false } })
        #expect(sources.contains { if case .video(_, _, let duration) = $0.content { duration == 4.5 } else { false } })
        #expect(sources.contains { if case .reflection("A note-only memory") = $0.content { true } else { false } })
    }

    @Test func legacyPhotoDraftsDecodeWithTheNewMemoryModel() throws {
        let original = SharedMoment(
            challengeID: UUID(), creatorID: UUID(), note: "Still compatible",
            localAssetName: "legacy.jpg", mediaKind: .photo, mediaMimeType: "image/jpeg"
        )
        let encoded = try JSONEncoder().encode(original)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "mediaKind")
        object.removeValue(forKey: "mediaMimeType")
        object.removeValue(forKey: "durationSeconds")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(SharedMoment.self, from: legacyData)
        #expect(decoded.mediaKind == .photo)
        #expect(decoded.localAssetName == "legacy.jpg")
        #expect(decoded.note == "Still compatible")
    }

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
