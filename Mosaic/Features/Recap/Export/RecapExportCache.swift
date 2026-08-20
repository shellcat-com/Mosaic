import AVFoundation
import CryptoKit
import Foundation

actor RecapExportCache {
    static let shared = RecapExportCache()
    private let manager = FileManager.default
    private let limit: Int64 = 750 * 1_024 * 1_024

    private var directory: URL {
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("RecapExports", isDirectory: true)
        try? manager.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try? mutable.setResourceValues(values)
        return url
    }

    func fingerprint(for request: RecapExportRequest) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let payload = RecapFingerprintPayload(
            challengeID: request.meta.challengeID,
            sources: request.sources.map {
                .init(sourceID: $0.id, origin: $0.origin, mediaVersion: $0.mediaVersion, consentVersion: $0.consentVersion)
            }.sorted { $0.sourceID.uuidString < $1.sourceID.uuidString },
            presetID: request.presetID,
            musicID: request.audio.trackID,
            trimOffset: request.audio.trimOffset,
            options: request.options,
            mosaicVersion: request.meta.mosaicVersion,
            impactReceiptVersion: request.meta.impact.version,
            rendererVersion: request.rendererVersion,
            reduceMotion: request.reduceMotion,
            localeIdentifier: request.meta.localeIdentifier,
            timeZoneIdentifier: request.meta.timeZoneIdentifier,
            musicManifestChecksum: RecapMusicCatalog.manifestChecksum
        )
        let digest = SHA256.hash(data: try encoder.encode(payload))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func cachedURL(for request: RecapExportRequest) async -> URL? {
        guard let fingerprint = try? fingerprint(for: request) else { return nil }
        let url = directory.appendingPathComponent("\(fingerprint).mp4")
        guard manager.fileExists(atPath: url.path) else { return nil }
        let asset = AVURLAsset(url: url)
        guard (try? await asset.load(.isPlayable)) == true,
              let video = try? await asset.loadTracks(withMediaType: .video).first,
              let size = try? await video.load(.naturalSize), size == CGSize(width: 1080, height: 1920) else {
            try? manager.removeItem(at: url)
            return nil
        }
        try? manager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return url
    }

    func store(_ source: URL, for request: RecapExportRequest) throws -> URL {
        let target = directory.appendingPathComponent("\(try fingerprint(for: request)).mp4")
        if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
        try manager.copyItem(at: source, to: target)
        trimIfNeeded()
        return target
    }

    private func trimIfNeeded() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) else { return }
        let records = files.compactMap { url -> (URL, Int64, Date)? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var total = records.reduce(Int64(0)) { $0 + $1.1 }
        for record in records where total > limit {
            try? manager.removeItem(at: record.0)
            total -= record.1
        }
    }
}

private struct RecapFingerprintPayload: Encodable {
    struct Source: Encodable {
        let sourceID: UUID
        let origin: RecapSourceOrigin
        let mediaVersion: Int
        let consentVersion: Int
    }

    let challengeID: UUID
    let sources: [Source]
    let presetID: String
    let musicID: String?
    let trimOffset: TimeInterval
    let options: RecapDetailsOptions
    let mosaicVersion: Int
    let impactReceiptVersion: Int
    let rendererVersion: Int
    let reduceMotion: Bool
    let localeIdentifier: String
    let timeZoneIdentifier: String
    let musicManifestChecksum: String
}
