import Foundation

protocol MosaicAPI: Sendable {
    func listMosaics() async throws -> [MosaicSummary]
    func createMosaic(_ draft: MosaicDraft) async throws -> MosaicEvent
    func createPremiumMosaic(_ draft: MosaicDraft, requestID: UUID) async throws -> MosaicEvent
    func billingSnapshot() async throws -> BillingSnapshot
    func refreshBilling() async throws -> BillingSnapshot
    func resolveInvitation(_ code: String) async throws -> MosaicInvitationPreview
    func joinMosaic(_ code: String) async throws -> MosaicEvent
    func loadMosaic(_ id: UUID) async throws -> MosaicEvent
    func updateMosaic(_ id: UUID, name: String, description: String) async throws -> MosaicEvent
    func deleteMosaic(_ id: UUID) async throws
    func completeActivity(mosaicID: UUID, activityID: UUID, note: String?) async throws -> KindnessContribution
    func updateContribution(_ id: UUID, note: String?) async throws -> KindnessContribution
    func withdrawContribution(_ id: UUID) async throws
    func preparePhoto(mosaicID: UUID, photoID: UUID, byteCount: Int, pixelWidth: Int, pixelHeight: Int) async throws -> PreparedPhotoUpload
    func uploadPhoto(_ upload: PreparedPhotoUpload, jpeg: Data) async throws
    func finalizePhoto(_ photoID: UUID) async throws -> EventPhoto
    func deletePhoto(_ photoID: UUID) async throws
    func reportPhoto(_ photoID: UUID, reason: String) async throws
    func blockUser(_ userID: UUID) async throws
    func unblockUser(_ userID: UUID) async throws
    func blockedUsers() async throws -> [BlockedUser]
    func releaseArtwork(_ mosaicID: UUID) async throws -> ArtworkRevealMaterial?
}

struct BlockedUser: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let blockedAt: Date
}
