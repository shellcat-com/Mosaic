import SwiftUI
import UIKit

struct TileFrontBoard: View {
    let goal: Int
    let occupiedPositions: [Int]
    private var side: Int { Int(Double(goal).squareRoot()) }
    private var occupied: Set<Int> { Set(occupiedPositions) }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: side), spacing: 6) {
            ForEach(0..<goal, id: \.self) { position in
                CeramicTileFront(position: position, isContributed: occupied.contains(position), compact: side > 7)
                    .accessibilityLabel(occupied.contains(position) ? "Contributed tile" : "Unfilled tile")
            }
        }
        .padding(8)
        .background(MosaicTheme.claySurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MosaicTheme.border, lineWidth: 1)
        }
        .shadow(color: MosaicTheme.warmShadow, radius: 8, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kindness board, \(occupied.count) of \(goal) tiles contributed")
    }
}

struct CeramicTileFront: View {
    let position: Int
    let isContributed: Bool
    var compact = false

    private var radius: CGFloat { compact ? 5 : 10 }
    private var glaze: Color { MosaicTheme.glazePalette[position % MosaicTheme.glazePalette.count] }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.white.opacity(isContributed ? 0.38 : 0.82), lineWidth: 1)
                    .padding(2)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.72), .clear, .black.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: compact ? 1 : 2
                    )
                    .padding(compact ? 1 : 2)
            }
            .overlay {
                if isContributed {
                    Image(systemName: "heart.fill")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                } else {
                    CeramicSpeckles(seed: position).clipShape(RoundedRectangle(cornerRadius: radius))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(isContributed ? glaze.opacity(0.8) : MosaicTheme.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: compact ? 1 : 2, y: compact ? 1 : 2)
            .shadow(color: MosaicTheme.warmShadow, radius: compact ? 2 : 5, y: compact ? 2 : 4)
    }

    private var fill: LinearGradient {
        LinearGradient(
            colors: isContributed
                ? [glaze.opacity(0.82), glaze, MosaicTheme.deepGlaze.opacity(0.92)]
                : [MosaicTheme.unglazedCeramic, MosaicTheme.unglazedCeramic.opacity(0.92), MosaicTheme.claySurface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct CeramicSpeckles: View {
    let seed: Int

    var body: some View {
        Canvas { context, size in
            for index in 0..<5 {
                let x = pseudo(index * 13 + seed * 7) * size.width
                let y = pseudo(index * 19 + seed * 11) * size.height
                let diameter = index.isMultiple(of: 2) ? 1.2 : 0.8
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                    with: .color(MosaicTheme.clay.opacity(0.22))
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func pseudo(_ value: Int) -> CGFloat {
        CGFloat((value * 37 + 17) % 97) / 97
    }
}

struct TileSideStory: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize { verticalStory }
            else { horizontalStory }
        }
        .porcelainCard()
        .accessibilityElement(children: .contain)
    }

    private var horizontalStory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                tileFace(CeramicTileFront(position: 1, isContributed: true), label: "FRONT · KINDNESS")
                Spacer(minLength: 4)
                VStack(spacing: 4) {
                    Image(systemName: "rotate.3d")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(MosaicTheme.clay)
                        .accessibilityHidden(true)
                    Text("AT REVEAL")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(MosaicTheme.muted)
                }
                Spacer(minLength: 4)
                tileFace(SealedArtworkFace(), label: "BACK · ARTWORK")
            }
            Text("Every act places the kindness face. At reveal, every tile turns and the other face becomes one shared artwork.")
                .font(.caption)
                .foregroundStyle(MosaicTheme.muted)
        }
    }

    private var verticalStory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                tileFace(CeramicTileFront(position: 1, isContributed: true), label: "FRONT · KINDNESS")
                Image(systemName: "rotate.3d")
                    .foregroundStyle(MosaicTheme.clay)
                    .accessibilityHidden(true)
                tileFace(SealedArtworkFace(), label: "BACK · ARTWORK")
            }
            Text("Every act places the kindness face. At reveal, every tile turns and the other face becomes one shared artwork.")
                .font(.body).foregroundStyle(MosaicTheme.muted)
        }
    }

    private func tileFace<Face: View>(_ face: Face, label: String) -> some View {
        VStack(spacing: 4) {
            face.frame(width: 56, height: 56)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(MosaicTheme.muted)
        }
    }
}

struct SealedArtworkFace: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(colors: [MosaicTheme.deepGlaze, MosaicTheme.sky, MosaicTheme.rose], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { Image(systemName: "sparkles").foregroundStyle(.white.opacity(0.9)) }
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.45)) }
            .accessibilityLabel("Artwork sealed until reveal")
    }
}

struct ArtworkRevealBoard: View {
    let event: MosaicEvent
    let decryptedArtworkURL: URL?
    let playback: RevealPlaybackStore
    private var side: Int { Int(Double(event.goal).squareRoot()) }

    init(event: MosaicEvent, decryptedArtworkURL: URL?, playback: RevealPlaybackStore) {
        self.event = event
        self.decryptedArtworkURL = decryptedArtworkURL
        self.playback = playback
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                artworkImage
                    .frame(width: proxy.size.width, height: proxy.size.width).clipped()
                    .accessibilityLabel(event.artwork.altText)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: side), spacing: 1) {
                    ForEach(0..<event.goal, id: \.self) { position in
                        CeramicTileFront(position: position, isContributed: event.occupiedTilePositions.contains(position), compact: side > 7)
                            .opacity(playback.uncoveredPositions.contains(position) ? 0 : 1)
                            .rotation3DEffect(
                                .degrees(playback.uncoveredPositions.contains(position) ? 92 : 0),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.42
                            )
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.width)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Revealed artwork: \(event.artwork.title) by \(event.artwork.artist). \(event.artwork.altText)")
        .accessibilityValue(playback.isComplete ? "Reveal complete" : "Revealing")
        .accessibilityIdentifier("artwork.reveal.board")
    }

    @ViewBuilder private var artworkImage: some View {
        if let decryptedArtworkURL,
           let image = UIImage(contentsOfFile: decryptedArtworkURL.path()) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Image(event.artwork.assetName).resizable().scaledToFill()
        }
    }

}

struct KindnessTileBoard: View {
    let event: MosaicEvent
    let openContribution: (UUID) -> Void
    private var side: Int { Int(Double(event.goal).squareRoot()) }
    private var contributionByPosition: [Int: KindnessContribution] {
        Dictionary(uniqueKeysWithValues: event.contributions.map { ($0.tilePosition, $0) })
    }
    private var orderedContributions: [KindnessContribution] {
        event.contributions.sorted { $0.tilePosition < $1.tilePosition }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: side), spacing: 6) {
                ForEach(0..<event.goal, id: \.self) { position in
                    if let contribution = contributionByPosition[position] {
                        Button { openContribution(contribution.id) } label: {
                            CeramicTileFront(position: position, isContributed: true, compact: side > 7)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open kindness contribution from \(contribution.contributorDisplayName ?? "a member")")
                        .accessibilityHidden(side > 7)
                    } else {
                        CeramicTileFront(position: position, isContributed: false, compact: side > 7)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(8)
            .background(MosaicTheme.claySurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(MosaicTheme.border) }
            .shadow(color: MosaicTheme.warmShadow, radius: 8, y: 4)
            .accessibilityElement(children: side > 7 ? .ignore : .contain)
            .accessibilityLabel("Kindness board with \(event.contributions.count) contributed tiles")

            if side > 7, !orderedContributions.isEmpty {
                DisclosureGroup("Browse kindness contributions") {
                    VStack(spacing: 0) {
                        ForEach(orderedContributions) { contribution in
                            Button {
                                openContribution(contribution.id)
                            } label: {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(MosaicTheme.accentForeground)
                                    Text(contribution.contributorDisplayName ?? "A member")
                                    Spacer()
                                    Text("Tile \(contribution.tilePosition + 1)")
                                        .foregroundStyle(MosaicTheme.muted)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(MosaicTheme.muted)
                                        .accessibilityHidden(true)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open kindness contribution from \(contribution.contributorDisplayName ?? "a member"), tile \(contribution.tilePosition + 1)")
                            if contribution.id != orderedContributions.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .porcelainCard()
            }
        }
    }
}
