import SwiftUI

struct CeramicTile: View {
    let category: MissionCategory
    let emotion: Emotion
    var evidence: EvidenceMethod = .reflection
    var isRevived = false
    var size: CGFloat = 66

    var body: some View {
        ZStack {
            OrganicPanelShape(variant: .softRectangle)
                .fill(
                    LinearGradient(
                        colors: [emotion.color.opacity(0.98), emotion.color.opacity(0.72), emotion.color.opacity(0.88)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            speckle
                .clipShape(OrganicPanelShape(variant: .softRectangle))
            DoodleIcon(icon: category.mosaicIcon, color: MosaicTheme.ink.opacity(0.52), lineWidth: max(1.5, size * 0.032))
                .frame(width: size * 0.42, height: size * 0.42)
                .shadow(color: .white.opacity(0.42), radius: 0, x: 0, y: 1)
            if isRevived {
                Path { path in
                    path.move(to: CGPoint(x: size * 0.08, y: size * 0.72))
                    path.addLine(to: CGPoint(x: size * 0.34, y: size * 0.48))
                    path.addLine(to: CGPoint(x: size * 0.55, y: size * 0.58))
                    path.addLine(to: CGPoint(x: size * 0.9, y: size * 0.22))
                }
                .stroke(MosaicTheme.gold, style: StrokeStyle(lineWidth: max(1.5, size * 0.035), lineCap: .round, lineJoin: .round))
                .shadow(color: MosaicTheme.gold.opacity(0.7), radius: 4)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            OrganicPanelShape(variant: .softRectangle)
                .stroke(Color.white.opacity(0.5), lineWidth: 1.1)
        }
        .overlay { OrganicPanelShape(variant: .softRectangle, inset: 2).stroke(MosaicTheme.ink.opacity(0.08), lineWidth: 0.7) }
        .shadow(color: Color.black.opacity(0.2), radius: size * 0.08, x: 0, y: size * 0.06)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(emotion.title) \(category.title) tile, verified by \(evidence.title)\(isRevived ? ", revived chain" : "")")
    }

    private var speckle: some View {
        Canvas { context, canvasSize in
            let count = evidence == .reflection ? 18 : evidence == .photo ? 32 : 24
            for index in 0..<count {
                let x = CGFloat((index * 37 + evidence.rawValue.count * 7) % 97) / 97 * canvasSize.width
                let y = CGFloat((index * 61 + category.rawValue.count * 5) % 89) / 89 * canvasSize.height
                let dot = CGRect(x: x, y: y, width: evidence == .video ? 1.8 : 1.1, height: 1.1)
                context.fill(Path(ellipseIn: dot), with: .color(MosaicTheme.ink.opacity(0.12)))
            }
        }
    }
}

struct MosaicBoard: View {
    let contributions: [TileContribution]
    var columns = 5
    var tileSize: CGFloat = 58
    var showOpenPosition = false

    var body: some View {
        let grid = Array(repeating: GridItem(.fixed(tileSize), spacing: 5), count: columns)
        LazyVGrid(columns: grid, spacing: 5) {
            ForEach(contributions) { contribution in
                CeramicTile(
                    category: contribution.mission.category,
                    emotion: contribution.emotion,
                    evidence: contribution.evidence,
                    isRevived: contribution.isRevived,
                    size: tileSize
                )
            }
            if showOpenPosition {
                OrganicPanelShape(variant: .softRectangle)
                    .stroke(MosaicTheme.indigo, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6]))
                    .frame(width: tileSize, height: tileSize)
                    .accessibilityLabel("Open tile position")
            }
        }
        .padding(10)
        .background(MosaicTheme.claySurface, in: OrganicPanelShape(variant: .leaningLeft))
        .overlay {
            OrganicPanelShape(variant: .leaningLeft)
                .stroke(MosaicTheme.border, lineWidth: 1.5)
        }
    }
}

struct MetricPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MosaicTheme.ink.opacity(0.82))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(MosaicTheme.paper, in: HandDrawnCapsule(inset: 0))
            .overlay { HandDrawnCapsule(inset: 1).stroke(MosaicTheme.border.opacity(0.7), lineWidth: 0.8) }
    }
}
