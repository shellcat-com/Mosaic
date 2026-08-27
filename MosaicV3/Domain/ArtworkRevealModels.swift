import Foundation

struct ArtworkRevealMaterial: Sendable {
    let mosaicID: UUID
    let ciphertext: Data
    let checksum: String
    let keyBase64: String
    let nonceBase64: String

    var additionalAuthenticatedData: Data {
        Data("mosaic-reveal:\(mosaicID.uuidString.lowercased())".utf8)
    }
}

enum ArtworkRevealError: LocalizedError, Equatable {
    case invalidKey
    case invalidNonce
    case invalidPackage
    case checksumMismatch
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidKey: "The artwork reveal key is invalid."
        case .invalidNonce: "The artwork reveal nonce is invalid."
        case .invalidPackage: "The encrypted artwork package is invalid."
        case .checksumMismatch: "The artwork package failed its integrity check."
        case .invalidImage: "The revealed artwork is not a valid image."
        }
    }
}
