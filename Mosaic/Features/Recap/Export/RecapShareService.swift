import Photos
import SwiftUI
import UIKit

enum RecapShareService {
    enum StaticCardKind: Equatable { case finalMosaic, impactReceipt }

    static func saveToPhotos(_ url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw CocoaError(.userCancelled) }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    static func activityItems(videoURL: URL, music: RecapMusicTrack?) -> [Any] {
        var items: [Any] = [videoURL]
        if let attribution = music?.attribution { items.append("Created with Mosaic\nMusic: \(attribution)") }
        return items
    }

    static func makeStaticCard(request: RecapRenderRequest, kind: StaticCardKind) throws -> URL {
        let segment = request.timeline.segments.first {
            $0.phase == (kind == .finalMosaic ? .finalReveal : .impactReceipt)
        } ?? request.timeline.segments.last!
        let time = segment.start + segment.duration * (kind == .finalMosaic ? 0.98 : 0.5)
        guard let image = RecapFrameRenderer().makeImage(request: request, time: time, size: CGSize(width: 1080, height: 1920)),
              let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.92) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let label = kind == .finalMosaic ? "final-mosaic" : "impact-receipt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mosaic-\(label)-\(UUID().uuidString).jpg")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }
}

struct RecapActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
