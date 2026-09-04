import SwiftUI
import UIKit

enum MosaicBoardMode: Equatable {
    case sealed
    case revealing
    case artwork
    case tiles
}

struct MosaicBoardView: View {
    let challenge: KindnessChallenge
    var mode: MosaicBoardMode = .sealed
    var revealProgress: Double = 0
    var croppedArtworkImage: UIImage?
    var predictedPosition: Int?
    var emphasizedPosition: Int?
    var spacing: CGFloat = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if challenge.artworkMode == .legacy {
            MosaicBoard(
                contributions: challenge.contributions,
                columns: 5,
                tileSize: 52,
                showOpenPosition: mode == .sealed
            )
        } else if let sealed = challenge.sealedArtwork {
            museumBoard(sealed)
        }
    }

    private func museumBoard(_ sealed: SealedArtwork) -> some View {
        let geometry = BoardGeometry(side: sealed.boardSide)
        let positioned = positionedContributions(capacity: geometry.capacity)
        return GeometryReader { proxy in
            let dimension = min(proxy.size.width, proxy.size.height)
            let tileSize = (dimension - spacing * CGFloat(geometry.side - 1)) / CGFloat(geometry.side)
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(tileSize), spacing: spacing),
                    count: geometry.side
                ),
                spacing: spacing
            ) {
                ForEach(0..<geometry.capacity, id: \.self) { position in
                    museumTile(
                        position: position,
                        contribution: positioned[position],
                        geometry: geometry,
                        tileSize: tileSize,
                        boardDimension: tileSize * CGFloat(geometry.side)
                    )
                }
            }
            .frame(width: dimension, height: dimension)
            .padding(4)
            .background(sealedBackground(sealed), in: .rect(cornerRadius: 10))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Mosaic board, \(challenge.contributions.count) of \(sealed.capacity) tiles placed"
        )
    }

    @ViewBuilder
    private func museumTile(
        position: Int,
        contribution: TileContribution?,
        geometry: BoardGeometry,
        tileSize: CGFloat,
        boardDimension: CGFloat
    ) -> some View {
        let localProgress: Double = switch mode {
        case .revealing:
            geometry.localRevealProgress(for: position, globalProgress: revealProgress)
        case .artwork:
            1
        case .sealed, .tiles:
            0
        }
        let eased = localProgress * localProgress * (3 - 2 * localProgress)
        let angle = eased * 180
        let cornerRadius = max(2, tileSize * 0.12)

        ZStack {
            if reduceMotion {
                tileFront(contribution, position: position, size: tileSize, cornerRadius: cornerRadius)
                    .opacity(1 - eased)
                artworkBack(
                    contribution,
                    position: position,
                    geometry: geometry,
                    tileSize: tileSize,
                    boardDimension: boardDimension,
                    cornerRadius: cornerRadius
                )
                .opacity(eased)
            } else {
                tileFront(contribution, position: position, size: tileSize, cornerRadius: cornerRadius)
                    .opacity(angle <= 90 ? 1 : 0)
                    .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                artworkBack(
                    contribution,
                    position: position,
                    geometry: geometry,
                    tileSize: tileSize,
                    boardDimension: boardDimension,
                    cornerRadius: cornerRadius
                )
                .opacity(angle > 90 ? 1 : 0)
                .rotation3DEffect(.degrees(angle - 180), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            }

            if contribution?.isRevived == true, eased > 0.55 {
                KintsugiSeam()
                    .stroke(MosaicTheme.gold, style: StrokeStyle(lineWidth: max(1, tileSize * 0.025), lineCap: .round))
                    .padding(tileSize * 0.08)
                    .opacity(min(1, (eased - 0.55) / 0.25))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: tileSize, height: tileSize)
        .zIndex(emphasizedPosition == position ? 2 : 0)
        .scaleEffect(rippleScale(for: position, geometry: geometry))
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: emphasizedPosition)
        .accessibilityLabel(tileAccessibilityLabel(contribution, position: position))
    }

    @ViewBuilder
    private func tileFront(
        _ contribution: TileContribution?,
        position: Int,
        size: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        if let contribution {
            CeramicTile(
                category: contribution.mission.category,
                emotion: contribution.emotion,
                evidence: contribution.evidence,
                isRevived: contribution.isRevived,
                size: size
            )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            predictedPosition == position ? MosaicTheme.indigo : Color(.separator),
                            style: StrokeStyle(
                                lineWidth: predictedPosition == position ? 2 : 1,
                                dash: predictedPosition == position ? [5, 4] : []
                            )
                        )
                }
                .shadow(
                    color: predictedPosition == position ? MosaicTheme.indigo.opacity(0.3) : .clear,
                    radius: 8
                )
        }
    }

    @ViewBuilder
    private func artworkBack(
        _ contribution: TileContribution?,
        position: Int,
        geometry: BoardGeometry,
        tileSize: CGFloat,
        boardDimension: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        if contribution != nil, let croppedArtworkImage {
            Image(uiImage: croppedArtworkImage)
                .resizable()
                .frame(width: boardDimension, height: boardDimension)
                .offset(
                    x: -CGFloat(geometry.column(for: position)) * tileSize,
                    y: -CGFloat(geometry.row(for: position)) * tileSize
                )
                .frame(width: tileSize, height: tileSize, alignment: .topLeading)
                .clipped()
                .clipShape(.rect(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }

    private func positionedContributions(capacity: Int) -> [Int: TileContribution] {
        var result: [Int: TileContribution] = [:]
        for (fallback, contribution) in challenge.contributions.enumerated() {
            let position = contribution.tilePosition ?? fallback
            guard position >= 0, position < capacity, result[position] == nil else { continue }
            result[position] = contribution
        }
        return result
    }

    private func rippleScale(for position: Int, geometry: BoardGeometry) -> CGFloat {
        guard let emphasizedPosition else { return 1 }
        if emphasizedPosition == position { return 1.06 }
        let distance = abs(geometry.row(for: emphasizedPosition) - geometry.row(for: position))
            + abs(geometry.column(for: emphasizedPosition) - geometry.column(for: position))
        return distance == 1 ? 1.025 : 1
    }

    private func sealedBackground(_ sealed: SealedArtwork) -> some ShapeStyle {
        let colors = sealed.palette.prefix(3).map(Color.init(hexString:))
        return AnyShapeStyle(LinearGradient(
            colors: colors.isEmpty ? [Color(.secondarySystemBackground)] : colors.map { $0.opacity(0.16) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
    }

    private func tileAccessibilityLabel(_ contribution: TileContribution?, position: Int) -> String {
        if let contribution {
            return "Tile \(position + 1), \(contribution.mission.category.title), \(contribution.emotion.title)"
        }
        return predictedPosition == position ? "Open tile position \(position + 1)" : "Empty tile position \(position + 1)"
    }
}

enum MuseumArtworkImage {
    static func crop(_ image: UIImage, to normalizedCrop: NormalizedArtworkCrop) -> UIImage? {
        guard let source = image.cgImage else { return nil }
        let width = CGFloat(source.width)
        let height = CGFloat(source.height)
        let rect = CGRect(
            x: CGFloat(normalizedCrop.x) * width,
            y: CGFloat(normalizedCrop.y) * height,
            width: CGFloat(normalizedCrop.width) * width,
            height: CGFloat(normalizedCrop.height) * height
        ).integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard rect.width > 0, rect.height > 0, let cropped = source.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}

private struct KintsugiSeam: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.72))
        path.addLine(to: CGPoint(x: rect.midX * 0.82, y: rect.midY * 1.08))
        path.addLine(to: CGPoint(x: rect.midX * 1.18, y: rect.midY * 0.86))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.24))
        return path
    }
}

private extension Color {
    init(hexString: String) {
        let normalized = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(normalized, radix: 16) ?? 0x7A74C9
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
