import Foundation

enum EventPhotoState: String, Codable, Hashable, Sendable {
    case localDraft
    case uploadPending
    case sealed
    case eligible
    case quarantined
    case deleted
}

struct EventPhoto: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let mosaicID: UUID
    let photographerID: UUID
    let photographerDisplayName: String
    let filmLookID: FilmLookID
    let capturedAt: Date
    var state: EventPhotoState
    var storagePath: String?
    var localURL: URL?
    var signedURL: URL?
    let pixelWidth: Int
    let pixelHeight: Int
    let isMine: Bool

    var displayURL: URL? { localURL ?? signedURL }
}

struct PreparedPhotoUpload: Codable, Hashable, Sendable {
    let photoID: UUID
    let path: String
    let token: String
}
