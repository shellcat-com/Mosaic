import CoreGraphics
import Testing
@testable import Mosaic

struct BoardGeometryTests {
    @Test(arguments: MuseumBoardSize.sides)
    func everySupportedBoardMapsAllTilesWithoutGaps(side: Int) {
        let geometry = BoardGeometry(side: side)
        let crop = NormalizedArtworkCrop(x: 0.1, y: 0.2, width: 0.6, height: 0.6)
        var area = 0.0

        for position in 0..<geometry.capacity {
            let rect = geometry.normalizedArtworkRect(for: position, approvedCrop: crop)
            #expect(rect.minX >= crop.x)
            #expect(rect.minY >= crop.y)
            #expect(rect.maxX <= crop.x + crop.width + 0.000_001)
            #expect(rect.maxY <= crop.y + crop.height + 0.000_001)
            #expect(abs(rect.width - crop.width / Double(side)) < 0.000_001)
            #expect(abs(rect.height - crop.height / Double(side)) < 0.000_001)
            area += rect.width * rect.height
        }

        #expect(abs(area - crop.width * crop.height) < 0.000_001)
    }

    @Test(arguments: MuseumBoardSize.sides)
    func viewRecapAndPosterFramesUseTheSameGeometry(side: Int) {
        let geometry = BoardGeometry(side: side)
        let position = geometry.capacity - 1
        let viewFrame = geometry.tileFrame(
            for: position,
            in: CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )
        let recapFrame = geometry.tileFrame(
            for: position,
            in: CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )
        let posterFrame = geometry.tileFrame(
            for: position,
            in: CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )

        #expect(viewFrame == recapFrame)
        #expect(recapFrame == posterFrame)
        #expect(abs(viewFrame.maxX - 1000) < 0.000_001)
        #expect(abs(viewFrame.maxY - 1000) < 0.000_001)
    }

    @Test func centerOutRevealStartsInTheCenterAndEndsAtCorners() {
        let geometry = BoardGeometry(side: 5)
        #expect(geometry.centerOutDistance(for: 12) == 0)
        #expect(geometry.localRevealProgress(for: 12, globalProgress: 0.25) > 0)
        #expect(geometry.localRevealProgress(for: 0, globalProgress: 0.25) == 0)
        #expect(geometry.localRevealProgress(for: 0, globalProgress: 1) == 1)
    }

    @Test func firstOpenPositionIgnoresOrderingAndFindsTheFirstGap() {
        let geometry = BoardGeometry(side: 3)
        #expect(geometry.firstOpenPosition(occupied: [0, 1, 3, 4]) == 2)
        #expect(geometry.firstOpenPosition(occupied: Set(0..<9)) == nil)
    }
}
