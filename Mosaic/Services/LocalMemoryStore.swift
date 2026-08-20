import Foundation
import UIKit

enum LocalMemoryStore {
    private static var directory: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let url = support.appendingPathComponent("MosaicMemories", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        return url
    }

    static func storeSanitizedJPEG(_ data: Data, id: UUID) -> String? {
        guard let image = UIImage(data: data), let rendered = image.normalized(maxDimension: 2_400),
              let output = rendered.jpegData(compressionQuality: 0.88), let directory else { return nil }
        let name = "\(id.uuidString.lowercased()).jpg"
        do {
            try output.write(
                to: directory.appendingPathComponent(name),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            return name
        } catch {
            return nil
        }
    }

    static func url(for name: String?) -> URL? {
        guard let name, let directory else { return nil }
        let url = directory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

private extension UIImage {
    func normalized(maxDimension: CGFloat) -> UIImage? {
        let factor = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: max(1, size.width * factor), height: max(1, size.height * factor))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: target))
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
