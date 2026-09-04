import CoreGraphics
import Foundation

enum RecapMissionCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case encouragement, giving, community, teaching, support, connection
}

enum RecapEmotion: String, Codable, Hashable, Sendable {
    case hopeful, joyful, caring, calm
}

struct RecapMediaAsset: Codable, Hashable, Sendable {
    let localURL: URL?
    let remotePath: String?
    let version: Int
    let pixelWidth: Int?
    let pixelHeight: Int?
}

enum RecapMemoryContent: Codable, Hashable, Sendable {
    case photo(asset: RecapMediaAsset, note: String?)
    case video(asset: RecapMediaAsset, note: String?, duration: TimeInterval?)
    case reflection(String)
    case tileOnly

    var hasPhoto: Bool {
        if case .photo = self { return true }
        return false
    }

    var hasVisualMedia: Bool {
        switch self {
        case .photo, .video: true
        case .reflection, .tileOnly: false
        }
    }
}

struct RecapEligibility: Codable, Hashable, Sendable {
    let accepted: Bool
    let recapConsent: Bool
    let mediaExists: Bool
    let isDeleted: Bool
    let isReported: Bool
    let contributorIsBlocked: Bool
    let viewerIsAuthorized: Bool

    var isEligible: Bool {
        accepted && recapConsent && mediaExists && !isDeleted && !isReported && !contributorIsBlocked && viewerIsAuthorized
    }
}

struct RecapTileDescriptor: Codable, Hashable, Sendable {
    let category: RecapMissionCategory
    let emotion: RecapEmotion
    let isRevived: Bool
    let finalPosition: Int
}

enum RecapSourceOrigin: String, Codable, Hashable, Sendable {
    case contribution
    case sharedMoment = "shared_moment"
}

struct RecapSource: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var origin: RecapSourceOrigin = .contribution
    let contributionID: UUID?
    let participantID: UUID
    let participantDisplayName: String?
    let attributionAllowed: Bool
    let category: RecapMissionCategory?
    let acceptedAt: Date
    let content: RecapMemoryContent
    let tile: RecapTileDescriptor?
    let eligibility: RecapEligibility
    let mediaVersion: Int
    let consentVersion: Int
    let perceptualHash: UInt64?
    let blurScore: Double?
}

protocol RecapDataProviding: Sendable {
    func loadRecap(challengeID: UUID) async throws -> (RecapMeta, [RecapSource])
}

protocol RecapMediaLoading: Sendable {
    func image(for asset: RecapMediaAsset, maximumPixelSize: CGFloat) async throws -> CGImage
}

protocol RecapExportRecording: Sendable {
    func record(_ status: RecapExportStatus, request: RecapExportRequest, progress: Double, outputPath: String?, error: String?) async throws
}

protocol RecapCloudPublishing: Sendable {
    func publish(file: URL, request: RecapExportRequest) async throws -> String
}
