import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let width = 720
let height = 1280
let framesPerSecond = 30
let duration = 7.0
let frameCount = Int(duration * Double(framesPerSecond))

guard CommandLine.arguments.count == 3 else {
    fputs("usage: render_reveal_prototype <artwork.jpg> <frames-directory>\n", stderr)
    exit(2)
}

let artworkURL = URL(fileURLWithPath: CommandLine.arguments[1])
let framesURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: framesURL, withIntermediateDirectories: true)

guard
    let imageSource = CGImageSourceCreateWithURL(artworkURL as CFURL, nil),
    let artwork = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
else {
    fputs("unable to load artwork\n", stderr)
    exit(3)
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
let board = CGRect(x: 60, y: 300, width: 600, height: 600)
let columns = 5
let rows = 5
let gap: CGFloat = 7
let tileWidth = (board.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
let tileHeight = (board.height - gap * CGFloat(rows - 1)) / CGFloat(rows)

let porcelain = CGColor(red: 0.984, green: 0.973, blue: 0.945, alpha: 1)
let kiln = CGColor(red: 0.075, green: 0.063, blue: 0.055, alpha: 1)
let ivory = CGColor(red: 0.969, green: 0.945, blue: 0.906, alpha: 1)
let ink = CGColor(red: 0.145, green: 0.133, blue: 0.122, alpha: 1)
let gold = CGColor(red: 0.839, green: 0.663, blue: 0.216, alpha: 1)
let glazes: [CGColor] = [
    CGColor(red: 0.49, green: 0.60, blue: 0.51, alpha: 1),
    CGColor(red: 0.49, green: 0.72, blue: 0.80, alpha: 1),
    CGColor(red: 0.89, green: 0.65, blue: 0.71, alpha: 1),
    CGColor(red: 0.96, green: 0.43, blue: 0.24, alpha: 1),
    CGColor(red: 0.35, green: 0.28, blue: 0.95, alpha: 1),
]

func clamp(_ value: Double, _ lower: Double = 0, _ upper: Double = 1) -> Double {
    min(max(value, lower), upper)
}

func smoothstep(_ value: Double) -> Double {
    let x = clamp(value)
    return x * x * (3 - 2 * x)
}

func mix(_ a: CGColor, _ b: CGColor, _ amount: Double) -> CGColor {
    let av = a.components ?? [0, 0, 0, 1]
    let bv = b.components ?? [0, 0, 0, 1]
    let t = CGFloat(clamp(amount))
    return CGColor(
        red: av[0] + (bv[0] - av[0]) * t,
        green: av[1] + (bv[1] - av[1]) * t,
        blue: av[2] + (bv[2] - av[2]) * t,
        alpha: 1
    )
}

func roundedPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func tileRect(position: Int) -> CGRect {
    let row = position / columns
    let column = position % columns
    return CGRect(
        x: board.minX + CGFloat(column) * (tileWidth + gap),
        y: board.minY + CGFloat(row) * (tileHeight + gap),
        width: tileWidth,
        height: tileHeight
    )
}

func sourceCrop(position: Int) -> CGImage? {
    let sourceSide = min(artwork.width, artwork.height)
    let sourceOriginX = (artwork.width - sourceSide) / 2
    let sourceOriginY = (artwork.height - sourceSide) / 2
    let row = position / columns
    let column = position % columns
    let cellWidth = sourceSide / columns
    let cellHeight = sourceSide / rows
    let crop = CGRect(
        x: sourceOriginX + column * cellWidth,
        y: sourceOriginY + row * cellHeight,
        width: cellWidth,
        height: cellHeight
    )
    return artwork.cropping(to: crop)
}

let artworkTiles = (0..<(columns * rows)).map(sourceCrop)

func drawText(
    _ text: String,
    in context: CGContext,
    top: CGFloat,
    size: CGFloat,
    color: CGColor,
    weight: NSFont.Weight = .regular
) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: color) ?? .white,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    let bounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
    context.saveGState()
    context.textMatrix = .identity
    context.textPosition = CGPoint(x: (CGFloat(width) - bounds.width) / 2 - bounds.minX, y: CGFloat(height) - top - size)
    CTLineDraw(line, context)
    context.restoreGState()
}

func drawCeramicFront(in context: CGContext, rect: CGRect, position: Int, scaleX: CGFloat) {
    let scaled = CGRect(
        x: rect.midX - rect.width * scaleX / 2,
        y: rect.minY,
        width: rect.width * scaleX,
        height: rect.height
    )
    guard scaled.width > 0.5 else { return }
    context.saveGState()
    context.addPath(roundedPath(scaled, radius: 16 * scaleX))
    context.setFillColor(glazes[position % glazes.count])
    context.fillPath()
    context.addPath(roundedPath(scaled.insetBy(dx: 5 * scaleX, dy: 5), radius: 12 * scaleX))
    context.setStrokeColor(ivory.copy(alpha: 0.42)!)
    context.setLineWidth(2)
    context.strokePath()

    if scaleX > 0.45 {
        let symbolRect = scaled.insetBy(dx: scaled.width * 0.33, dy: scaled.height * 0.33)
        context.setStrokeColor(ink.copy(alpha: 0.42)!)
        context.setLineWidth(4)
        switch position % 3 {
        case 0:
            context.strokeEllipse(in: symbolRect)
        case 1:
            context.move(to: CGPoint(x: symbolRect.midX, y: symbolRect.minY))
            context.addLine(to: CGPoint(x: symbolRect.minX, y: symbolRect.maxY))
            context.addLine(to: CGPoint(x: symbolRect.maxX, y: symbolRect.maxY))
            context.closePath()
            context.strokePath()
        default:
            context.move(to: CGPoint(x: symbolRect.minX, y: symbolRect.midY))
            context.addLine(to: CGPoint(x: symbolRect.maxX, y: symbolRect.midY))
            context.move(to: CGPoint(x: symbolRect.midX, y: symbolRect.minY))
            context.addLine(to: CGPoint(x: symbolRect.midX, y: symbolRect.maxY))
            context.strokePath()
        }
    }
    context.restoreGState()
}

func drawArtworkBack(in context: CGContext, rect: CGRect, position: Int, scaleX: CGFloat) {
    guard let tile = artworkTiles[position] else { return }
    let scaled = CGRect(
        x: rect.midX - rect.width * scaleX / 2,
        y: rect.minY,
        width: rect.width * scaleX,
        height: rect.height
    )
    guard scaled.width > 0.5 else { return }
    context.saveGState()
    context.addPath(roundedPath(scaled, radius: 10 * scaleX))
    context.clip()
    context.draw(tile, in: scaled)
    context.restoreGState()
    context.addPath(roundedPath(scaled, radius: 10 * scaleX))
    context.setStrokeColor(ivory.copy(alpha: 0.36)!)
    context.setLineWidth(1.5)
    context.strokePath()
}

func writePNG(context: CGContext, frame: Int) throws {
    guard let image = context.makeImage() else { throw NSError(domain: "render", code: 1) }
    let outputURL = framesURL.appendingPathComponent(String(format: "frame-%04d.png", frame))
    guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "render", code: 2)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "render", code: 3) }
}

for frame in 0..<frameCount {
    autoreleasepool {
        let time = Double(frame) / Double(framesPerSecond)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        let darken = smoothstep((time - 0.65) / 1.0)
        context.setFillColor(mix(porcelain, kiln, darken))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let headlineColor = mix(ink, ivory, darken)
        drawText(time < 4.9 ? "THE KILN IS OPENING" : "TOGETHER, WE MADE THIS", in: context, top: 108, size: 27, color: headlineColor, weight: .semibold)
        drawText(time < 4.9 ? "Every tile has a place" : "One shared artwork", in: context, top: 154, size: 17, color: headlineColor.copy(alpha: 0.68)!)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: ink.copy(alpha: CGFloat(0.18 + darken * 0.2)))
        context.addPath(roundedPath(board.insetBy(dx: -18, dy: -18), radius: 34))
        context.setFillColor(mix(CGColor(red: 0.92, green: 0.88, blue: 0.80, alpha: 1), CGColor(red: 0.18, green: 0.13, blue: 0.09, alpha: 1), darken))
        context.fillPath()
        context.restoreGState()

        let wave = clamp((time - 1.45) / 3.85)
        for position in 0..<(columns * rows) {
            let row = position / columns
            let column = position % columns
            let dx = Double(column - 2)
            let dy = Double(row - 2)
            let distance = sqrt(dx * dx + dy * dy) / sqrt(8.0)
            let delay = distance * 0.42 + Double((row + column) % 2) * 0.025
            let local = smoothstep((wave - delay) / 0.34)
            let cosine = cos(Double.pi * local)
            let rect = tileRect(position: position)
            if local < 0.5 {
                drawCeramicFront(in: context, rect: rect, position: position, scaleX: CGFloat(max(0, cosine)))
            } else {
                drawArtworkBack(in: context, rect: rect, position: position, scaleX: CGFloat(max(0, -cosine)))
            }
        }

        if time > 2.8 && time < 5.3 {
            let seamProgress = smoothstep((time - 2.8) / 1.4) * (1 - smoothstep((time - 4.65) / 0.55))
            context.saveGState()
            context.setStrokeColor(gold.copy(alpha: CGFloat(seamProgress * 0.88))!)
            context.setLineWidth(4)
            context.setShadow(offset: .zero, blur: 12, color: gold.copy(alpha: 0.7))
            let center = CGPoint(x: board.midX, y: board.midY)
            context.move(to: CGPoint(x: center.x - 72, y: center.y - 96))
            context.addLine(to: CGPoint(x: center.x - 22, y: center.y - 28))
            context.addLine(to: CGPoint(x: center.x - 54, y: center.y + 24))
            context.addLine(to: CGPoint(x: center.x + 12, y: center.y + 88))
            context.addLine(to: CGPoint(x: center.x + 76, y: center.y + 54))
            context.strokePath()
            context.restoreGState()
        }

        let receiptProgress = smoothstep((time - 5.3) / 0.75)
        if receiptProgress > 0 {
            let receiptY = 70 - CGFloat((1 - receiptProgress) * 120)
            let receipt = CGRect(x: 80, y: receiptY, width: 560, height: 190)
            let receiptTop = CGFloat(height) - receipt.maxY
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: CGColor(gray: 0, alpha: 0.24))
            context.addPath(roundedPath(receipt, radius: 28))
            context.setFillColor(ivory.copy(alpha: CGFloat(receiptProgress))!)
            context.fillPath()
            context.restoreGState()
            drawText("IMPACT RECEIPT", in: context, top: receiptTop + 34, size: 22, color: ink.copy(alpha: CGFloat(receiptProgress))!, weight: .semibold)
            drawText("25 acts of kindness  •  25 equal tiles", in: context, top: receiptTop + 88, size: 17, color: ink.copy(alpha: CGFloat(receiptProgress * 0.72))!)
        }

        do {
            try writePNG(context: context, frame: frame)
        } catch {
            fputs("failed to write frame \(frame): \(error)\n", stderr)
            exit(4)
        }
    }
}

print("rendered \(frameCount) frames")
