import Foundation
import Testing
@testable import Mosaic

struct PhotoDiskStoreTests {
    @Test
    func pendingUploadManifestSurvivesStoreRecreation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "MosaicPhotoDiskStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let mosaicID = UUID()
        let photoID = UUID()
        let firstStore = PhotoDiskStore(baseDirectory: root)
        let localURL = try await firstStore.save(Data([0xFF, 0xD8, 0xFF, 0xD9]), id: photoID)
        let pending = EventPhoto(
            id: photoID,
            mosaicID: mosaicID,
            photographerID: UUID(),
            photographerDisplayName: "You",
            filmLookID: .garden,
            capturedAt: .now,
            state: .uploadPending,
            storagePath: nil,
            localURL: localURL,
            signedURL: nil,
            pixelWidth: 100,
            pixelHeight: 100,
            isMine: true
        )
        try await firstStore.savePending(pending)

        let restored = try await PhotoDiskStore(baseDirectory: root).pendingPhotos(mosaicID: mosaicID)
        #expect(restored == [pending])

        try await firstStore.delete(id: photoID)
        let cleared = try await firstStore.pendingPhotos(mosaicID: mosaicID)
        #expect(cleared.isEmpty)
    }
}
