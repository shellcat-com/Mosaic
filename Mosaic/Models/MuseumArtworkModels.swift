import CoreGraphics
import Foundation

enum ArtworkMode: String, Codable, Hashable, Sendable {
    case legacy
    case museum
}

struct NormalizedArtworkCrop: Codable, Hashable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    static let full = NormalizedArtworkCrop(x: 0, y: 0, width: 1, height: 1)

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct SealedArtwork: Codable, Hashable, Sendable {
    let collection: KinderThemeCollection
    let palette: [String]
    let boardSide: Int

    var capacity: Int { boardSide * boardSide }
}

struct ArtworkCatalogItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let artistDisplay: String
    let dateDisplay: String
    let sourceURL: URL
    let altText: String
    let collection: KinderThemeCollection
    let dominantColors: [String]
    let thumbnailURL: URL?
    let licenseLabel: String
    let catalogRevision: Int
    let sourceWidth: Int
    let sourceHeight: Int
    let crop: NormalizedArtworkCrop
}

struct ArtworkCatalogResponse: Codable, Sendable {
    let enabled: Bool
    let artworks: [ArtworkCatalogItem]
}

struct RevealArtworkPrefetch: Codable, Hashable, Sendable {
    let ciphertextURL: URL
    let packageRevision: Int
    let checksum: String
    let byteCount: Int
}

struct RevealedArtwork: Codable, Hashable, Sendable {
    let id: UUID
    let museumArtworkId: Int
    let title: String
    let artistDisplay: String
    let dateDisplay: String
    let sourceURL: URL
    let altText: String
    let licenseLabel: String
    let crop: NormalizedArtworkCrop
}

struct RevealedArtworkResponse: Codable, Sendable {
    let packageRevision: Int
    let checksum: String
    let key: String
    let nonce: String
    let aad: String
    let exportURL: URL
    let exportChecksum: String
    let artwork: RevealedArtwork
}

enum MuseumBoardSize {
    static let sides = Array(3...10)
    static let capacities = sides.map { $0 * $0 }
    static let defaultSide = 5

    static func isSupported(side: Int) -> Bool {
        sides.contains(side)
    }
}

enum MuseumArtworkAvailability: Equatable, Sendable {
    case idle
    case prefetching
    case sealedReady
    case unlocking
    case reconnecting(String)
    case ready
}
