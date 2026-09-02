import Testing
import UIKit
@testable import Mosaic

struct DisposableCameraFilterTests {
    @Test func developingAPhotoPreservesItsDisplayOrientationAndBounds() throws {
        let source = testJPEG(size: CGSize(width: 640, height: 360))
        let output = try #require(
            DisposableCameraFilter.developJPEG(source, look: .sunwashed, maximumDimension: 320)
        )
        let image = try #require(UIImage(data: output))

        #expect(image.imageOrientation == .up)
        #expect(image.size == CGSize(width: 320, height: 180))
        #expect(output != source)
    }

    @Test func everyGroupFilmLookDevelopsAValidJPEG() throws {
        let source = testJPEG(size: CGSize(width: 180, height: 240))

        for look in FilmLookID.allCases {
            let output = try #require(DisposableCameraFilter.developJPEG(source, look: look))
            let image = try #require(UIImage(data: output))
            #expect(image.size == CGSize(width: 180, height: 240))
        }
    }

    private func testJPEG(size: CGSize) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor(red: 0.42, green: 0.55, blue: 0.68, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            context.fill(CGRect(x: size.width * 0.25, y: size.height * 0.25,
                                width: size.width * 0.5, height: size.height * 0.5))
        }
        return image.jpegData(compressionQuality: 0.95)!
    }
}
