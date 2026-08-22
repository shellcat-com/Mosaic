import Foundation
import Testing
@testable import Mosaic

struct BackendModelTests {
    @Test func contributionLifecycleExposesPlacementRules() {
        #expect(ContributionStatus.pendingReview.needsModeration)
        #expect(!ContributionStatus.pendingReview.canPlace)
        #expect(ContributionStatus.selfAttested.canPlace)
        #expect(ContributionStatus.verified.canPlace)
    }

    @Test func snakeCaseRecordsDecodeFromSupabasePayloads() throws {
        let payload = """
        {
          "id":"11111111-1111-4111-8111-111111111111",
          "organization_id":"22222222-2222-4222-8222-222222222222",
          "name":"A Kinder Block",
          "purpose":"Test",
          "goal":40,
          "reveal_at":"2026-08-24T00:00:00Z",
          "status":"active",
          "invitation_code":"KIND42",
          "is_showcase":true
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let challenge = try decoder.decode(ChallengeRecord.self, from: payload)

        #expect(challenge.name == "A Kinder Block")
        #expect(challenge.organizationId == UUID(uuidString: "22222222-2222-4222-8222-222222222222"))
        #expect(challenge.invitationCode == "KIND42")
        #expect(challenge.isShowcase)
    }

    @Test func evidenceDraftKeepsConsentIndependent() {
        let draft = EvidenceDraft(
            id: UUID(), challengeID: UUID(), missionID: UUID(), emotion: .caring,
            method: .reflection, reflection: "A moment", mediaData: nil, mimeType: nil,
            durationSeconds: nil, includeMemory: true, showIdentity: false, exportConsent: false
        )
        #expect(draft.includeMemory)
        #expect(!draft.showIdentity)
        #expect(!draft.exportConsent)
    }

    @Test func uploadPolicyEnforcesImageAndVideoLimits() throws {
        try EvidenceUploadPolicy.validate(
            method: .photo,
            byteCount: EvidenceUploadPolicy.maximumImageBytes,
            duration: nil
        )
        #expect(throws: EvidenceUploadValidationError.imageTooLarge) {
            try EvidenceUploadPolicy.validate(
                method: .receipt,
                byteCount: EvidenceUploadPolicy.maximumImageBytes + 1,
                duration: nil
            )
        }
        #expect(throws: EvidenceUploadValidationError.videoTooLarge) {
            try EvidenceUploadPolicy.validate(
                method: .video,
                byteCount: EvidenceUploadPolicy.maximumVideoBytes + 1,
                duration: 5
            )
        }
        #expect(throws: EvidenceUploadValidationError.invalidVideoDuration) {
            try EvidenceUploadPolicy.validate(method: .video, byteCount: 1, duration: 10.01)
        }
    }
}
