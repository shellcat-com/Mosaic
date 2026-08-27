import Foundation
import Observation
import UIKit

@MainActor @Observable
final class CameraStore {
    private let api: any MosaicAPI
    private let diskStore: PhotoDiskStore
    private let analyzer: SensitivePhotoAnalyzer
    private(set) var selectedEvent: MosaicSummary?
    private(set) var ownPhotos: [EventPhoto] = []
    private(set) var reviewJPEG: Data?
    private(set) var isProcessing = false
    var message: String?

    init(api: any MosaicAPI, diskStore: PhotoDiskStore = .init(), analyzer: SensitivePhotoAnalyzer = .init()) {
        self.api = api
        self.diskStore = diskStore
        self.analyzer = analyzer
    }

    var shotsUsed: Int { ownPhotos.filter { $0.state != .deleted }.count }
    var shotsRemaining: Int { max(0, (selectedEvent?.shotLimit ?? 0) - shotsUsed) }
    var canCapture: Bool { selectedEvent?.phase.acceptsPhotos == true && shotsRemaining > 0 && !isProcessing }

    func select(_ event: MosaicSummary?) {
        selectedEvent = event
        ownPhotos = []
        reviewJPEG = nil
    }

    func synchronize(with event: MosaicEvent) {
        selectedEvent = event.summary
        ownPhotos = event.photos.filter(\.isMine)
    }

    func prepareReview(rawPhotoData: Data) async {
        guard let event = selectedEvent, canCapture else { return }
        isProcessing = true
        defer { isProcessing = false }
        guard let developed = DisposableCameraFilter.developJPEG(rawPhotoData, look: event.filmLookID) else {
            message = "Mosaic could not develop that frame. Please retake it."
            return
        }
        do {
            guard try await !analyzer.isSensitive(developed) else { throw MosaicAPIError.sensitivePhoto }
            reviewJPEG = developed
            message = nil
        } catch {
            reviewJPEG = nil
            message = error.localizedDescription
        }
    }

    func retake() {
        reviewJPEG = nil
    }

    func keepReview() async throws {
        guard let event = selectedEvent, let jpeg = reviewJPEG, canCapture,
              let image = UIImage(data: jpeg) else { return }
        isProcessing = true
        defer { isProcessing = false }
        let photoID = UUID()
        let localURL = try await diskStore.save(jpeg, id: photoID)
        do {
            let upload = try await api.preparePhoto(
                mosaicID: event.id, photoID: photoID, byteCount: jpeg.count,
                pixelWidth: Int(image.size.width), pixelHeight: Int(image.size.height)
            )
            try await api.uploadPhoto(upload, jpeg: jpeg)
            var photo = try await api.finalizePhoto(photoID)
            photo.localURL = localURL
            try? await diskStore.clearPending(id: photoID)
            ownPhotos.append(photo)
            reviewJPEG = nil
        } catch {
            let pending = EventPhoto(
                id: photoID, mosaicID: event.id, photographerID: UUID(), photographerDisplayName: "You",
                filmLookID: event.filmLookID, capturedAt: .now, state: .uploadPending,
                storagePath: nil, localURL: localURL, signedURL: nil,
                pixelWidth: Int(image.size.width), pixelHeight: Int(image.size.height), isMine: true
            )
            try? await diskStore.savePending(pending)
            ownPhotos.append(pending)
            reviewJPEG = nil
            message = "The photo is safe on this device and will retry when Mosaic reconnects."
            throw error
        }
    }

    func restorePendingPhotos() async {
        guard let event = selectedEvent,
              let restored = try? await diskStore.pendingPhotos(mosaicID: event.id) else { return }
        for photo in restored where !ownPhotos.contains(where: { $0.id == photo.id }) {
            ownPhotos.append(photo)
        }
    }

    func retryPendingUploads() async {
        guard let event = selectedEvent, event.phase.acceptsPhotos else { return }
        let pendingPhotos = ownPhotos.filter { $0.state == .uploadPending }
        for pending in pendingPhotos {
            guard let localURL = pending.localURL,
                  let jpeg = try? Data(contentsOf: localURL) else { continue }
            do {
                let upload = try await api.preparePhoto(
                    mosaicID: event.id, photoID: pending.id, byteCount: jpeg.count,
                    pixelWidth: pending.pixelWidth, pixelHeight: pending.pixelHeight
                )
                do {
                    try await api.uploadPhoto(upload, jpeg: jpeg)
                } catch {
                    // A previous attempt may have uploaded successfully before its response was lost.
                    // Finalization below distinguishes that case from a genuinely missing upload.
                }
                var finalized = try await api.finalizePhoto(pending.id)
                finalized.localURL = localURL
                if let index = ownPhotos.firstIndex(where: { $0.id == pending.id }) {
                    ownPhotos[index] = finalized
                }
                try? await diskStore.clearPending(id: pending.id)
                message = nil
            } catch {
                message = "A sealed photo is waiting for a connection. Mosaic will try again here."
            }
        }
    }

    func delete(_ photo: EventPhoto) async throws {
        if photo.state == .uploadPending { try? await api.deletePhoto(photo.id) }
        else { try await api.deletePhoto(photo.id) }
        try? await diskStore.delete(id: photo.id)
        ownPhotos.removeAll { $0.id == photo.id }
    }
}
