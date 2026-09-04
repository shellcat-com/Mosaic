import CryptoKit
import Foundation

enum RevealArtworkCryptoError: LocalizedError, Equatable {
    case invalidKey
    case invalidNonce
    case invalidPackage
    case checksumMismatch
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidKey: "The reveal key is invalid."
        case .invalidNonce: "The reveal nonce is invalid."
        case .invalidPackage: "The encrypted artwork package is invalid."
        case .checksumMismatch: "The artwork package failed its integrity check."
        case .invalidImage: "The revealed artwork could not be decoded."
        }
    }
}

protocol RevealArtworkDecrypting: Sendable {
    func decrypt(
        ciphertext: Data,
        keyBase64: String,
        nonceBase64: String,
        aad: String
    ) throws -> Data
}

struct CryptoKitRevealArtworkDecryptor: RevealArtworkDecrypting {
    func decrypt(
        ciphertext: Data,
        keyBase64: String,
        nonceBase64: String,
        aad: String
    ) throws -> Data {
        guard let keyData = Data(base64Encoded: keyBase64), keyData.count == 32 else {
            throw RevealArtworkCryptoError.invalidKey
        }
        guard let nonceData = Data(base64Encoded: nonceBase64), nonceData.count == 12 else {
            throw RevealArtworkCryptoError.invalidNonce
        }
        guard ciphertext.count > 16 else {
            throw RevealArtworkCryptoError.invalidPackage
        }

        let nonce = try AES.GCM.Nonce(data: nonceData)
        let tag = ciphertext.suffix(16)
        let encryptedBytes = ciphertext.dropLast(16)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: encryptedBytes,
            tag: tag
        )
        return try AES.GCM.open(
            sealedBox,
            using: SymmetricKey(data: keyData),
            authenticating: Data(aad.utf8)
        )
    }
}

actor RevealArtworkCache {
    private let fileManager: FileManager
    private let session: URLSession
    private let decryptor: any RevealArtworkDecrypting
    private let rootDirectory: URL

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        decryptor: any RevealArtworkDecrypting = CryptoKitRevealArtworkDecryptor(),
        rootDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.session = session
        self.decryptor = decryptor
        self.rootDirectory = rootDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MuseumReveal", isDirectory: true)
    }

    func prefetch(_ package: RevealArtworkPrefetch, challengeID: UUID) async throws -> URL {
        let url = ciphertextURL(challengeID: challengeID, revision: package.packageRevision)
        if try checksum(at: url) == package.checksum { return url }

        let (data, response) = try await session.data(from: package.ciphertextURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard data.count == package.byteCount, Self.sha256(data) == package.checksum else {
            throw RevealArtworkCryptoError.checksumMismatch
        }
        try store(data, at: url)
        return url
    }

    func decrypt(
        _ response: RevealedArtworkResponse,
        challengeID: UUID
    ) throws -> URL {
        let destination = displayURL(challengeID: challengeID, revision: response.packageRevision)
        if fileManager.fileExists(atPath: destination.path) { return destination }

        let encryptedURL = ciphertextURL(challengeID: challengeID, revision: response.packageRevision)
        let ciphertext = try Data(contentsOf: encryptedURL, options: .mappedIfSafe)
        guard Self.sha256(ciphertext) == response.checksum else {
            throw RevealArtworkCryptoError.checksumMismatch
        }
        let plaintext = try decryptor.decrypt(
            ciphertext: ciphertext,
            keyBase64: response.key,
            nonceBase64: response.nonce,
            aad: response.aad
        )
        guard !plaintext.isEmpty else { throw RevealArtworkCryptoError.invalidImage }
        try store(plaintext, at: destination)
        return destination
    }

    func cacheExport(
        _ response: RevealedArtworkResponse,
        challengeID: UUID
    ) async throws -> URL {
        let destination = exportURL(challengeID: challengeID, revision: response.packageRevision)
        if try checksum(at: destination) == response.exportChecksum { return destination }

        let (data, urlResponse) = try await session.data(from: response.exportURL)
        guard (urlResponse as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard Self.sha256(data) == response.exportChecksum else {
            throw RevealArtworkCryptoError.checksumMismatch
        }
        try store(data, at: destination)
        return destination
    }

    func cachedDisplayURL(challengeID: UUID, revision: Int) -> URL? {
        let url = displayURL(challengeID: challengeID, revision: revision)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func cachedExportURL(challengeID: UUID, revision: Int) -> URL? {
        let url = exportURL(challengeID: challengeID, revision: revision)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func storeMetadata(
        _ artwork: RevealedArtwork,
        challengeID: UUID,
        revision: Int
    ) throws {
        let data = try JSONEncoder().encode(artwork)
        try store(data, at: metadataURL(challengeID: challengeID, revision: revision))
    }

    func cachedMetadata(challengeID: UUID, revision: Int) throws -> RevealedArtwork? {
        let url = metadataURL(challengeID: challengeID, revision: revision)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(RevealedArtwork.self, from: Data(contentsOf: url))
    }

    private func store(_ data: Data, at url: URL) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func checksum(at url: URL) throws -> String? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return Self.sha256(try Data(contentsOf: url, options: .mappedIfSafe))
    }

    private func challengeDirectory(_ challengeID: UUID) -> URL {
        rootDirectory.appendingPathComponent(challengeID.uuidString.lowercased(), isDirectory: true)
    }

    private func ciphertextURL(challengeID: UUID, revision: Int) -> URL {
        challengeDirectory(challengeID).appendingPathComponent("package-\(revision).aesgcm")
    }

    private func displayURL(challengeID: UUID, revision: Int) -> URL {
        challengeDirectory(challengeID).appendingPathComponent("display-\(revision).jpg")
    }

    private func exportURL(challengeID: UUID, revision: Int) -> URL {
        challengeDirectory(challengeID).appendingPathComponent("export-\(revision).jpg")
    }

    private func metadataURL(challengeID: UUID, revision: Int) -> URL {
        challengeDirectory(challengeID).appendingPathComponent("metadata-\(revision).json")
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
