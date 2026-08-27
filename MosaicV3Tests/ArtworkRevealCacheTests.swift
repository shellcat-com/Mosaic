import CryptoKit
import Foundation
import Testing
import UIKit
@testable import Mosaic

struct ArtworkRevealCacheTests {
    @Test
    func verifiedAESGCMArtworkDecryptsIntoProtectedCache() async throws {
        let mosaicID = UUID()
        let root = FileManager.default.temporaryDirectory.appending(path: "ArtworkReveal-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        let plaintext = try #require(image.jpegData(compressionQuality: 0.8))
        let key = SymmetricKey(size: .bits256)
        let nonce = AES.GCM.Nonce()
        let aad = Data("mosaic-reveal:\(mosaicID.uuidString.lowercased())".utf8)
        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad)
        let ciphertext = sealed.ciphertext + sealed.tag
        let material = ArtworkRevealMaterial(
            mosaicID: mosaicID,
            ciphertext: ciphertext,
            checksum: SHA256.hash(data: ciphertext).map { String(format: "%02x", $0) }.joined(),
            keyBase64: key.withUnsafeBytes { Data($0).base64EncodedString() },
            nonceBase64: Data(nonce).base64EncodedString()
        )

        let url = try await ArtworkRevealCache(directory: root).decrypt(material)
        #expect(FileManager.default.fileExists(atPath: url.path()))
        #expect(UIImage(contentsOfFile: url.path()) != nil)
    }

    @Test
    func revealCacheRejectsTamperedCiphertextBeforeWriting() async {
        let root = FileManager.default.temporaryDirectory.appending(path: "ArtworkReveal-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let material = ArtworkRevealMaterial(
            mosaicID: UUID(),
            ciphertext: Data(repeating: 1, count: 32),
            checksum: String(repeating: "0", count: 64),
            keyBase64: Data(repeating: 2, count: 32).base64EncodedString(),
            nonceBase64: Data(repeating: 3, count: 12).base64EncodedString()
        )
        await #expect(throws: ArtworkRevealError.checksumMismatch) {
            try await ArtworkRevealCache(directory: root).decrypt(material)
        }
    }
}
