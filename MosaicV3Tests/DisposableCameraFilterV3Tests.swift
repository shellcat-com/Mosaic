import Testing
import UIKit
@testable import Mosaic

@MainActor
struct DisposableCameraFilterV3Tests {
    @Test(arguments: FilmLookID.allCases)
    func everyFilmLookProducesDevelopedJPEG(_ look: FilmLookID) throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 120)).image { context in
            UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
        }
        let input = try #require(source.jpegData(compressionQuality: 0.95))
        let output = try #require(DisposableCameraFilter.developJPEG(input, look: look, maximumDimension: 120))
        let image = try #require(UIImage(data: output))
        #expect(max(image.size.width, image.size.height) <= 120)
        #expect(output != input)
    }
}
