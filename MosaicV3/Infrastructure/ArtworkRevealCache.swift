import CryptoKit
import Foundation
import UIKit

actor ArtworkRevealCache {
    private let fileManager: FileManager
    private let directory: URL

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        self.directory = directory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "MosaicArtworkReveals", directoryHint: .isDirectory)
    }

    func decrypt(_ material: ArtworkRevealMaterial) throws -> URL {
        let destination = directory.appending(path: "\(material.mosaicID.uuidString.lowercased()).jpg")
        if fileManager.fileExists(atPath: destination.path()) { return destination }
        guard Self.sha256(material.ciphertext) == material.checksum.lowercased() else {
            throw ArtworkRevealError.checksumMismatch
        }
        guard let key = Data(base64Encoded: material.keyBase64), key.count == 32 else {
            throw ArtworkRevealError.invalidKey
        }
        guard let nonceData = Data(base64Encoded: material.nonceBase64), nonceData.count == 12 else {
            throw ArtworkRevealError.invalidNonce
        }
        guard material.ciphertext.count > 16 else { throw ArtworkRevealError.invalidPackage }
        let box = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: nonceData),
            ciphertext: material.ciphertext.dropLast(16),
            tag: material.ciphertext.suffix(16)
        )
        let imageData = try AES.GCM.open(
            box,
            using: SymmetricKey(data: key),
            authenticating: material.additionalAuthenticatedData
        )
        guard UIImage(data: imageData) != nil else { throw ArtworkRevealError.invalidImage }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try imageData.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return destination
    }

    func clearAll() throws {
        if fileManager.fileExists(atPath: directory.path()) {
            try fileManager.removeItem(at: directory)
        }
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
