import AVFoundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct PrivateMediaPicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let method: EvidenceMethod
    let onPicked: @MainActor (Data, Double?) -> Void
    let onError: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = method == .receipt
        picker.mediaTypes = method == .video ? [UTType.movie.identifier] : [UTType.image.identifier]
        picker.videoMaximumDuration = EvidenceUploadPolicy.maximumVideoDuration
        picker.videoQuality = .typeMedium
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: PrivateMediaPicker

        init(parent: PrivateMediaPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if parent.method == .video, let url = info[.mediaURL] as? URL {
                Task { @MainActor in
                    do {
                        let data = try Data(contentsOf: url)
                        let duration = try await AVURLAsset(url: url).load(.duration).seconds
                        try EvidenceUploadPolicy.validate(method: .video, byteCount: data.count, duration: duration)
                        parent.onPicked(data, duration)
                    } catch {
                        parent.onError(error.localizedDescription)
                    }
                    picker.dismiss(animated: true)
                }
                return
            }

            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            if let data = image?.jpegData(compressionQuality: 0.82) {
                do {
                    try EvidenceUploadPolicy.validate(method: parent.method, byteCount: data.count, duration: nil)
                    parent.onPicked(data, nil)
                } catch {
                    parent.onError(error.localizedDescription)
                }
            } else {
                parent.onError("That image could not be prepared.")
            }
            picker.dismiss(animated: true)
        }
    }
}

enum ReceiptImageProcessor {
    static func redact(_ data: Data, at normalizedPoint: CGPoint) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let result = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            context.cgContext.setFillColor(UIColor.black.cgColor)
            let width = image.size.width * 0.34
            let height = max(image.size.height * 0.055, 24)
            let center = CGPoint(x: normalizedPoint.x * image.size.width, y: normalizedPoint.y * image.size.height)
            let origin = CGPoint(
                x: min(max(center.x - width / 2, 0), image.size.width - width),
                y: min(max(center.y - height / 2, 0), image.size.height - height)
            )
            context.cgContext.fill(CGRect(origin: origin, size: CGSize(width: width, height: height)))
        }
        return result.jpegData(compressionQuality: 0.82)
    }
}
