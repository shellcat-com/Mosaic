import CoreGraphics
import Foundation

struct BoardGeometry: Hashable, Sendable {
    let side: Int

    init(side: Int) {
        precondition(MuseumBoardSize.isSupported(side: side), "Museum boards use sides 3 through 10")
        self.side = side
    }

    var capacity: Int { side * side }

    func row(for position: Int) -> Int {
        bounded(position) / side
    }

    func column(for position: Int) -> Int {
        bounded(position) % side
    }

    func normalizedArtworkRect(
        for position: Int,
        approvedCrop: NormalizedArtworkCrop
    ) -> CGRect {
        let tileWidth = approvedCrop.width / Double(side)
        let tileHeight = approvedCrop.height / Double(side)
        return CGRect(
            x: approvedCrop.x + Double(column(for: position)) * tileWidth,
            y: approvedCrop.y + Double(row(for: position)) * tileHeight,
            width: tileWidth,
            height: tileHeight
        )
    }

    func tileFrame(for position: Int, in bounds: CGRect, spacing: CGFloat = 0) -> CGRect {
        let totalSpacing = spacing * CGFloat(side - 1)
        let tileWidth = (bounds.width - totalSpacing) / CGFloat(side)
        let tileHeight = (bounds.height - totalSpacing) / CGFloat(side)
        return CGRect(
            x: bounds.minX + CGFloat(column(for: position)) * (tileWidth + spacing),
            y: bounds.minY + CGFloat(row(for: position)) * (tileHeight + spacing),
            width: tileWidth,
            height: tileHeight
        )
    }

    func sourcePixelRect(
        for position: Int,
        approvedCrop: NormalizedArtworkCrop,
        imageSize: CGSize
    ) -> CGRect {
        let normalized = normalizedArtworkRect(for: position, approvedCrop: approvedCrop)
        return CGRect(
            x: normalized.minX * imageSize.width,
            y: normalized.minY * imageSize.height,
            width: normalized.width * imageSize.width,
            height: normalized.height * imageSize.height
        )
    }

    func centerOutDistance(for position: Int) -> Double {
        let center = Double(side - 1) / 2
        let dx = Double(column(for: position)) - center
        let dy = Double(row(for: position)) - center
        let maximum = max(hypot(center, center), 1)
        return min(1, hypot(dx, dy) / maximum)
    }

    func localRevealProgress(
        for position: Int,
        globalProgress: Double,
        waveSpread: Double = 0.58
    ) -> Double {
        let start = centerOutDistance(for: position) * waveSpread
        return min(1, max(0, (globalProgress - start) / max(0.001, 1 - waveSpread)))
    }

    func firstOpenPosition(occupied: Set<Int>) -> Int? {
        (0..<capacity).first { !occupied.contains($0) }
    }

    private func bounded(_ position: Int) -> Int {
        min(max(position, 0), capacity - 1)
    }
}
