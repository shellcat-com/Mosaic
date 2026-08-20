import SwiftUI

struct CeramicTile: View {
    let category: MissionCategory
    let emotion: Emotion
    var evidence: EvidenceMethod = .reflection
    var isRevived: Bool = false
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [emotion.color.opacity(0.95), emotion.color.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .stroke(MosaicTheme.paper.opacity(0.8), lineWidth: max(2, size * 0.035))
                .padding(size * 0.08)
            Image(systemName: category.symbol)
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(MosaicTheme.paper)
            Image(systemName: evidence.symbol)
                .font(.system(size: size * 0.13, weight: .semibold))
                .foregroundStyle(MosaicTheme.paper)
                .padding(size * 0.08)
                .background(MosaicTheme.ink.opacity(0.22), in: Circle())
                .offset(x: size * 0.29, y: size * 0.29)
            if isRevived {
                Image(systemName: "sparkles")
                    .foregroundStyle(MosaicTheme.gold)
                    .offset(x: -size * 0.3, y: -size * 0.3)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: emotion.color.opacity(0.28), radius: size * 0.08, y: size * 0.05)
        .accessibilityLabel("\(category.title) tile, \(emotion.title)")
    }
}

struct MosaicBoard: View {
    let contributions: [TileContribution]
    var columns: Int = 5
    var tileSize: CGFloat = 52
    var showOpenPosition: Bool = false

    var body: some View {
        let safeColumns = max(columns, 1)
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(tileSize), spacing: 6), count: safeColumns),
            spacing: 6
        ) {
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
                RoundedRectangle(cornerRadius: tileSize * 0.2, style: .continuous)
                    .stroke(MosaicTheme.indigo.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .frame(width: tileSize, height: tileSize)
                    .accessibilityLabel("Open tile position")
            }
        }
    }
}
