import CryptoKit
import Foundation
import Testing
@testable import Mosaic

struct RevealArtworkCryptoTests {
    private let aad = "mosaic:challenge:catalog-1:package-1"

    @Test func decryptsWebCryptoCompatibleCiphertextAndTagPackage() throws {
        let plaintext = Data("museum artwork bytes".utf8)
        let key = SymmetricKey(size: .bits256)
        let nonce = AES.GCM.Nonce()
        let box = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: Data(aad.utf8))
        let package = box.ciphertext + box.tag

        let opened = try CryptoKitRevealArtworkDecryptor().decrypt(
            ciphertext: package,
            keyBase64: key.withUnsafeBytes { Data($0).base64EncodedString() },
            nonceBase64: Data(nonce).base64EncodedString(),
            aad: aad
        )

        #expect(opened == plaintext)
    }

    @Test func rejectsWrongKeyWrongAADAndTamperedCiphertext() throws {
        let key = SymmetricKey(size: .bits256)
        let nonce = AES.GCM.Nonce()
        let box = try AES.GCM.seal(Data("art".utf8), using: key, nonce: nonce, authenticating: Data(aad.utf8))
        var package = box.ciphertext + box.tag
        let nonceBase64 = Data(nonce).base64EncodedString()
        let keyBase64 = key.withUnsafeBytes { Data($0).base64EncodedString() }
        let wrongKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0).base64EncodedString() }

        #expect(throws: (any Error).self) {
            try CryptoKitRevealArtworkDecryptor().decrypt(
                ciphertext: package,
                keyBase64: wrongKey,
                nonceBase64: nonceBase64,
                aad: aad
            )
        }
        #expect(throws: (any Error).self) {
            try CryptoKitRevealArtworkDecryptor().decrypt(
                ciphertext: package,
                keyBase64: keyBase64,
                nonceBase64: nonceBase64,
                aad: "wrong challenge"
            )
        }

        package[package.startIndex] ^= 0x01
        #expect(throws: (any Error).self) {
            try CryptoKitRevealArtworkDecryptor().decrypt(
                ciphertext: package,
                keyBase64: keyBase64,
                nonceBase64: nonceBase64,
                aad: aad
            )
        }
    }

    @Test func validatesKeyNonceAndPackageLengthsBeforeOpening() {
        let decryptor = CryptoKitRevealArtworkDecryptor()
        #expect(throws: RevealArtworkCryptoError.invalidKey) {
            try decryptor.decrypt(ciphertext: Data(repeating: 0, count: 17), keyBase64: "bad", nonceBase64: "bad", aad: aad)
        }
        #expect(throws: RevealArtworkCryptoError.invalidNonce) {
            try decryptor.decrypt(
                ciphertext: Data(repeating: 0, count: 17),
                keyBase64: Data(repeating: 0, count: 32).base64EncodedString(),
                nonceBase64: "bad",
                aad: aad
            )
        }
        #expect(throws: RevealArtworkCryptoError.invalidPackage) {
            try decryptor.decrypt(
                ciphertext: Data(repeating: 0, count: 16),
                keyBase64: Data(repeating: 0, count: 32).base64EncodedString(),
                nonceBase64: Data(repeating: 0, count: 12).base64EncodedString(),
                aad: aad
            )
        }
    }
}
