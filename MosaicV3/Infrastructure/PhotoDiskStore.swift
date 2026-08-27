import Foundation

actor PhotoDiskStore {
    private let directory: URL

    init(baseDirectory: URL? = nil) {
        let root = baseDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = root.appending(path: "MosaicEventPhotos", directoryHint: .isDirectory)
    }

    func save(_ jpeg: Data, id: UUID) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(id.uuidString).jpg")
        try jpeg.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    func savePending(_ photo: EventPhoto) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(photo)
        try data.write(to: pendingURL(id: photo.id), options: [.atomic, .completeFileProtection])
    }

    func pendingPhotos(mosaicID: UUID) throws -> [EventPhoto] {
        guard FileManager.default.fileExists(atPath: directory.path()) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "pending" }
            .compactMap { url in try? JSONDecoder().decode(EventPhoto.self, from: Data(contentsOf: url)) }
            .filter { $0.mosaicID == mosaicID }
    }

    func clearPending(id: UUID) throws {
        let url = pendingURL(id: id)
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func delete(id: UUID) throws {
        let url = directory.appending(path: "\(id.uuidString).jpg")
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
        try clearPending(id: id)
    }

    private func pendingURL(id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).pending")
    }
}
