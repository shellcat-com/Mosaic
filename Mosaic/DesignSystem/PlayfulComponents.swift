import SwiftUI

enum OrganicPanelVariant: Int, CaseIterable {
    case softRectangle
    case leaningLeft
    case leaningRight
}

struct OrganicPanelShape: Shape {
    var variant: OrganicPanelVariant
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let target = rect.insetBy(dx: inset, dy: inset)
        let radius: CGFloat = variant == .softRectangle ? 22 : 28
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: target)
    }
}

struct HandDrawnCapsule: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        Capsule().path(in: rect.insetBy(dx: inset, dy: inset))
    }

    func inset(by amount: CGFloat) -> HandDrawnCapsule {
        var copy = self
        copy.inset += amount
        return copy
    }
}

struct MosaicScreen<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MosaicTheme.Spacing.screen)
                .padding(.vertical, MosaicTheme.Spacing.large)
        }
        .scrollIndicators(.hidden)
        .porcelainBackground()
    }
}

struct OrganicPanel<Content: View>: View {
    let variant: OrganicPanelVariant
    let tint: Color
    private let content: Content

    init(
        variant: OrganicPanelVariant = .softRectangle,
        tint: Color = MosaicTheme.paper,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: OrganicPanelShape(variant: variant))
            .overlay { OrganicPanelShape(variant: variant).stroke(MosaicTheme.border.opacity(0.8), lineWidth: 1) }
            .shadow(color: Color.black.opacity(0.07), radius: 10, y: 5)
    }
}

enum MosaicIcon: String, CaseIterable, Identifiable {
    case bulb, gift, home, kiln, leaf, tile, chain, hands, heart, spark, memory, mosaic, people, profile, kintsugi

    var id: String { rawValue }
    var accessibilityLabel: String { rawValue.capitalized }

    var systemName: String {
        switch self {
        case .bulb: "lightbulb.fill"
        case .gift: "gift.fill"
        case .home: "house.fill"
        case .kiln: "flame.fill"
        case .leaf: "leaf.fill"
        case .tile: "square.grid.3x3.fill"
        case .chain: "link"
        case .hands: "hands.sparkles.fill"
        case .heart: "heart.fill"
        case .spark: "sparkles"
        case .memory: "photo.on.rectangle.angled"
        case .mosaic: "square.grid.2x2.fill"
        case .people: "person.2.fill"
        case .profile: "person.crop.circle.fill"
        case .kintsugi: "seal.fill"
        }
    }
}

struct DoodleIcon: View {
    let icon: MosaicIcon
    var color: Color = MosaicTheme.ink
    var lineWidth: CGFloat = 2

    var body: some View {
        Image(systemName: icon.systemName)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
            .accessibilityLabel(icon.accessibilityLabel)
    }
}

enum MosaicStickerKind: CaseIterable, Hashable {
    case ceramicSun, giftRibbon, helpingHands, neighborhoodSprout, kindNote, sparkles

    var icon: MosaicIcon {
        switch self {
        case .ceramicSun, .sparkles: .spark
        case .giftRibbon: .gift
        case .helpingHands: .hands
        case .neighborhoodSprout: .leaf
        case .kindNote: .heart
        }
    }

    var tint: Color {
        switch self {
        case .ceramicSun: MosaicTheme.gold
        case .giftRibbon: MosaicTheme.persimmon
        case .helpingHands: MosaicTheme.rose
        case .neighborhoodSprout: MosaicTheme.sage
        case .kindNote: MosaicTheme.indigo
        case .sparkles: MosaicTheme.gold
        }
    }
}

struct MosaicSticker: View {
    let kind: MosaicStickerKind
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(MosaicTheme.paper)
            Circle().stroke(kind.tint.opacity(0.45), lineWidth: 2)
            DoodleIcon(icon: kind.icon, color: kind.tint, lineWidth: 2.5)
                .font(.system(size: size * 0.42, weight: .bold))
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.12), radius: 7, y: 4)
    }
}

struct MosaicSectionHeader: View {
    let title: String
    var eyebrow: String? = nil
    var icon: MosaicIcon? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let eyebrow {
                HStack(spacing: 7) {
                    if let icon { DoodleIcon(icon: icon, color: MosaicTheme.indigo).frame(width: 18, height: 18) }
                    Text(eyebrow.uppercased())
                }
                .font(MosaicTheme.caption(.bold))
                .foregroundStyle(MosaicTheme.indigo)
            }
            Text(title).font(MosaicTheme.display(34, weight: .semibold))
        }
        .foregroundStyle(MosaicTheme.ink)
        .accessibilityElement(children: .combine)
    }
}

struct MosaicProgressRail: View {
    let current: Int
    let total: Int
    var tint: Color = MosaicTheme.indigo

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(index < current ? tint : MosaicTheme.border)
                    .frame(height: 7)
            }
        }
        .animation(.easeInOut, value: current)
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = MosaicTheme.indigo

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MosaicTheme.body(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: MosaicTheme.minimumHitTarget)
            .padding(.horizontal, 18)
            .background(color.opacity(configuration.isPressed ? 0.78 : 1), in: HandDrawnCapsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = MosaicTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MosaicTheme.body(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: MosaicTheme.minimumHitTarget)
            .padding(.horizontal, 18)
            .background(MosaicTheme.paper.opacity(configuration.isPressed ? 0.7 : 1), in: HandDrawnCapsule())
            .overlay { HandDrawnCapsule(inset: 1).stroke(color.opacity(0.5), lineWidth: 1.5) }
    }
}

struct EditorialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MosaicTheme.body(.semibold))
            .foregroundStyle(MosaicTheme.indigo)
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct MetricPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(MosaicTheme.caption(.semibold))
            .foregroundStyle(MosaicTheme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(MosaicTheme.paper.opacity(0.8), in: Capsule())
    }
}
