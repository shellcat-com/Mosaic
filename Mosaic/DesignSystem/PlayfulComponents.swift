import SwiftUI

enum OrganicPanelVariant: Int, CaseIterable {
    case softRectangle
    case leaningLeft
    case leaningRight
}

struct OrganicPanelShape: Shape {
    let variant: OrganicPanelVariant
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        guard r.width > 0, r.height > 0 else { return Path() }

        let radius = min(30, r.height * 0.17)
        let topTilt: CGFloat = variant == .leaningLeft ? 5 : variant == .leaningRight ? -4 : 1
        let bottomTilt: CGFloat = variant == .leaningLeft ? -3 : variant == .leaningRight ? 5 : -1
        var path = Path()
        path.move(to: CGPoint(x: r.minX + radius, y: r.minY + topTilt))
        path.addCurve(
            to: CGPoint(x: r.maxX - radius, y: r.minY - topTilt * 0.2),
            control1: CGPoint(x: r.minX + r.width * 0.34, y: r.minY - 2),
            control2: CGPoint(x: r.minX + r.width * 0.72, y: r.minY + 3)
        )
        path.addCurve(
            to: CGPoint(x: r.maxX, y: r.minY + radius),
            control1: CGPoint(x: r.maxX - radius * 0.32, y: r.minY),
            control2: CGPoint(x: r.maxX, y: r.minY + radius * 0.4)
        )
        path.addCurve(
            to: CGPoint(x: r.maxX - 2, y: r.maxY - radius),
            control1: CGPoint(x: r.maxX + 2, y: r.minY + r.height * 0.36),
            control2: CGPoint(x: r.maxX - 4, y: r.minY + r.height * 0.76)
        )
        path.addCurve(
            to: CGPoint(x: r.maxX - radius, y: r.maxY + bottomTilt),
            control1: CGPoint(x: r.maxX - 1, y: r.maxY - radius * 0.36),
            control2: CGPoint(x: r.maxX - radius * 0.4, y: r.maxY)
        )
        path.addCurve(
            to: CGPoint(x: r.minX + radius, y: r.maxY - bottomTilt * 0.2),
            control1: CGPoint(x: r.minX + r.width * 0.7, y: r.maxY + 2),
            control2: CGPoint(x: r.minX + r.width * 0.3, y: r.maxY - 3)
        )
        path.addCurve(
            to: CGPoint(x: r.minX, y: r.maxY - radius),
            control1: CGPoint(x: r.minX + radius * 0.32, y: r.maxY),
            control2: CGPoint(x: r.minX, y: r.maxY - radius * 0.4)
        )
        path.addCurve(
            to: CGPoint(x: r.minX + radius, y: r.minY + topTilt),
            control1: CGPoint(x: r.minX - 2, y: r.minY + r.height * 0.72),
            control2: CGPoint(x: r.minX + 2, y: r.minY + radius * 0.35)
        )
        path.closeSubpath()
        return path
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
                .padding(.horizontal, MosaicTheme.Spacing.screen)
                .padding(.top, MosaicTheme.Spacing.small)
                .padding(.bottom, 36)
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
            .padding(MosaicTheme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: OrganicPanelShape(variant: variant))
            .overlay { OrganicPanelShape(variant: variant).stroke(MosaicTheme.border.opacity(0.68), lineWidth: 1) }
            .overlay { OrganicPanelShape(variant: variant, inset: 3).stroke(Color.white.opacity(0.25), lineWidth: 0.8) }
            .shadow(color: Color.black.opacity(0.08), radius: 14, y: 8)
    }
}

enum MosaicIcon: String, CaseIterable, Identifiable {
    case home, mosaic, profile
    case heart, leaf, gift, people, bulb, hands
    case spark, chain, kintsugi, kiln, tile, memory

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .home: "Home"
        case .mosaic: "Mosaics"
        case .profile: "You"
        case .heart: "Encouragement"
        case .leaf: "Community care"
        case .gift: "Giving"
        case .people: "Connection"
        case .bulb: "Teaching"
        case .hands: "Support"
        case .spark: "Spark"
        case .chain: "Pass the Tile chain"
        case .kintsugi: "Kintsugi repair"
        case .kiln: "Kiln"
        case .tile: "Ceramic tile"
        case .memory: "Shared memory"
        }
    }
}

struct DoodleIcon: View {
    let icon: MosaicIcon
    var color: Color = MosaicTheme.ink
    var lineWidth: CGFloat = 2.1

    var body: some View {
        DoodleGlyph(icon: icon)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .overlay {
                DoodleGlyph(icon: icon)
                    .stroke(color.opacity(0.28), style: StrokeStyle(lineWidth: max(0.7, lineWidth * 0.38), lineCap: .round, lineJoin: .round))
                    .offset(x: 1.1, y: -0.8)
            }
            .padding(2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(icon.accessibilityLabel)
    }
}

private struct DoodleGlyph: Shape {
    let icon: MosaicIcon

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * w, y: rect.minY + y * h) }
        var path = Path()

        switch icon {
        case .home:
            path.move(to: p(0.12, 0.48)); path.addLine(to: p(0.5, 0.14)); path.addLine(to: p(0.88, 0.48))
            path.move(to: p(0.22, 0.4)); path.addLine(to: p(0.22, 0.86)); path.addLine(to: p(0.78, 0.86)); path.addLine(to: p(0.78, 0.4))
            path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.43, y: rect.minY + h * 0.6, width: w * 0.17, height: h * 0.26), cornerSize: CGSize(width: 2, height: 2))
        case .mosaic:
            for row in 0..<3 { for column in 0..<3 {
                path.addRoundedRect(in: CGRect(x: rect.minX + w * (0.12 + CGFloat(column) * 0.27), y: rect.minY + h * (0.12 + CGFloat(row) * 0.27), width: w * 0.2, height: h * 0.2), cornerSize: CGSize(width: w * 0.045, height: h * 0.045))
            }}
        case .profile:
            path.addEllipse(in: CGRect(x: rect.minX + w * 0.36, y: rect.minY + h * 0.14, width: w * 0.28, height: h * 0.28))
            path.move(to: p(0.2, 0.82)); path.addCurve(to: p(0.8, 0.82), control1: p(0.25, 0.48), control2: p(0.75, 0.48))
        case .heart:
            path.move(to: p(0.5, 0.84)); path.addCurve(to: p(0.12, 0.37), control1: p(0.35, 0.7), control2: p(0.08, 0.56))
            path.addCurve(to: p(0.5, 0.3), control1: p(0.15, 0.12), control2: p(0.39, 0.17))
            path.addCurve(to: p(0.88, 0.37), control1: p(0.61, 0.17), control2: p(0.85, 0.12))
            path.addCurve(to: p(0.5, 0.84), control1: p(0.92, 0.56), control2: p(0.65, 0.7))
        case .leaf:
            path.move(to: p(0.16, 0.72)); path.addCurve(to: p(0.82, 0.18), control1: p(0.2, 0.3), control2: p(0.55, 0.15))
            path.addCurve(to: p(0.16, 0.72), control1: p(0.84, 0.62), control2: p(0.55, 0.88))
            path.move(to: p(0.2, 0.72)); path.addCurve(to: p(0.7, 0.32), control1: p(0.42, 0.63), control2: p(0.56, 0.46))
        case .gift:
            path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.16, y: rect.minY + h * 0.38, width: w * 0.68, height: h * 0.46), cornerSize: CGSize(width: 3, height: 3))
            path.move(to: p(0.5, 0.38)); path.addLine(to: p(0.5, 0.84)); path.move(to: p(0.12, 0.5)); path.addLine(to: p(0.88, 0.5))
            path.addEllipse(in: CGRect(x: rect.minX + w * 0.24, y: rect.minY + h * 0.18, width: w * 0.26, height: h * 0.2))
            path.addEllipse(in: CGRect(x: rect.minX + w * 0.5, y: rect.minY + h * 0.18, width: w * 0.26, height: h * 0.2))
        case .people:
            path.addEllipse(in: CGRect(x: rect.minX + w * 0.2, y: rect.minY + h * 0.18, width: w * 0.22, height: h * 0.22))
            path.addEllipse(in: CGRect(x: rect.minX + w * 0.58, y: rect.minY + h * 0.18, width: w * 0.22, height: h * 0.22))
            path.move(to: p(0.08, 0.78)); path.addCurve(to: p(0.5, 0.78), control1: p(0.12, 0.48), control2: p(0.45, 0.48))
            path.move(to: p(0.5, 0.78)); path.addCurve(to: p(0.92, 0.78), control1: p(0.55, 0.48), control2: p(0.88, 0.48))
        case .bulb:
            path.addEllipse(in: CGRect(x: rect.minX + w * 0.24, y: rect.minY + h * 0.12, width: w * 0.52, height: h * 0.55))
            path.move(to: p(0.36, 0.62)); path.addLine(to: p(0.39, 0.8)); path.addLine(to: p(0.61, 0.8)); path.addLine(to: p(0.64, 0.62))
            path.move(to: p(0.4, 0.9)); path.addLine(to: p(0.6, 0.9))
        case .hands:
            path.move(to: p(0.08, 0.58)); path.addCurve(to: p(0.48, 0.8), control1: p(0.22, 0.5), control2: p(0.32, 0.84))
            path.addCurve(to: p(0.72, 0.42), control1: p(0.58, 0.76), control2: p(0.64, 0.48))
            path.move(to: p(0.92, 0.42)); path.addCurve(to: p(0.52, 0.2), control1: p(0.78, 0.5), control2: p(0.68, 0.16))
            path.addCurve(to: p(0.28, 0.58), control1: p(0.42, 0.24), control2: p(0.36, 0.52))
        case .spark:
            path.move(to: p(0.5, 0.08)); path.addCurve(to: p(0.62, 0.42), control1: p(0.53, 0.28), control2: p(0.55, 0.36))
            path.addCurve(to: p(0.92, 0.5), control1: p(0.72, 0.46), control2: p(0.8, 0.48))
            path.addCurve(to: p(0.62, 0.58), control1: p(0.8, 0.52), control2: p(0.72, 0.54))
            path.addCurve(to: p(0.5, 0.92), control1: p(0.55, 0.64), control2: p(0.53, 0.74))
            path.addCurve(to: p(0.38, 0.58), control1: p(0.47, 0.74), control2: p(0.45, 0.64))
            path.addCurve(to: p(0.08, 0.5), control1: p(0.28, 0.54), control2: p(0.2, 0.52))
            path.addCurve(to: p(0.38, 0.42), control1: p(0.2, 0.48), control2: p(0.28, 0.46))
            path.addCurve(to: p(0.5, 0.08), control1: p(0.45, 0.36), control2: p(0.47, 0.28))
        case .chain:
            path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.07, y: rect.minY + h * 0.3, width: w * 0.5, height: h * 0.34), cornerSize: CGSize(width: h * 0.17, height: h * 0.17), transform: CGAffineTransform(rotationAngle: -0.35).translatedBy(x: -w * 0.18, y: h * 0.1))
            path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.43, y: rect.minY + h * 0.36, width: w * 0.5, height: h * 0.34), cornerSize: CGSize(width: h * 0.17, height: h * 0.17), transform: CGAffineTransform(rotationAngle: -0.35).translatedBy(x: -w * 0.18, y: h * 0.1))
        case .kintsugi:
            path.move(to: p(0.14, 0.88)); path.addLine(to: p(0.38, 0.6)); path.addLine(to: p(0.29, 0.42)); path.addLine(to: p(0.58, 0.27)); path.addLine(to: p(0.82, 0.08))
            path.move(to: p(0.38, 0.6)); path.addLine(to: p(0.65, 0.73)); path.move(to: p(0.58, 0.27)); path.addLine(to: p(0.76, 0.42))
        case .kiln:
            path.move(to: p(0.16, 0.86)); path.addLine(to: p(0.16, 0.42)); path.addCurve(to: p(0.84, 0.42), control1: p(0.24, 0.04), control2: p(0.76, 0.04)); path.addLine(to: p(0.84, 0.86)); path.closeSubpath()
            path.move(to: p(0.38, 0.82)); path.addCurve(to: p(0.56, 0.42), control1: p(0.25, 0.65), control2: p(0.52, 0.62)); path.addCurve(to: p(0.68, 0.82), control1: p(0.78, 0.6), control2: p(0.68, 0.73)); path.closeSubpath()
        case .tile:
            path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.13, y: rect.minY + h * 0.13, width: w * 0.74, height: h * 0.74), cornerSize: CGSize(width: w * 0.14, height: h * 0.14))
            path.move(to: p(0.3, 0.7)); path.addCurve(to: p(0.7, 0.3), control1: p(0.45, 0.72), control2: p(0.55, 0.28))
        case .memory:
            path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.18, y: rect.minY + h * 0.13, width: w * 0.64, height: h * 0.74), cornerSize: CGSize(width: 3, height: 3))
            path.move(to: p(0.34, 0.13)); path.addLine(to: p(0.34, 0.87))
            path.move(to: p(0.48, 0.42)); path.addCurve(to: p(0.68, 0.42), control1: p(0.52, 0.3), control2: p(0.64, 0.3)); path.addCurve(to: p(0.58, 0.64), control1: p(0.7, 0.54), control2: p(0.62, 0.6)); path.addCurve(to: p(0.48, 0.42), control1: p(0.54, 0.6), control2: p(0.46, 0.54))
        }
        return path
    }
}

enum MosaicStickerKind: CaseIterable {
    case sparkles, kindNote, helpingHands, neighborhoodSprout, giftRibbon, ceramicSun

    var icon: MosaicIcon {
        switch self {
        case .sparkles, .ceramicSun: .spark
        case .kindNote: .heart
        case .helpingHands: .hands
        case .neighborhoodSprout: .leaf
        case .giftRibbon: .gift
        }
    }

    var tint: Color {
        switch self {
        case .sparkles: MosaicTheme.gold
        case .kindNote: MosaicTheme.sky
        case .helpingHands: MosaicTheme.persimmon
        case .neighborhoodSprout: MosaicTheme.sage
        case .giftRibbon: MosaicTheme.rose
        case .ceramicSun: MosaicTheme.gold
        }
    }
}

struct MosaicSticker: View {
    let kind: MosaicStickerKind
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            OrganicPanelShape(variant: variant)
                .fill(kind.tint.opacity(0.28))
                .rotationEffect(.degrees(-4))
            OrganicPanelShape(variant: variant, inset: 3)
                .stroke(kind.tint.opacity(0.75), lineWidth: 1.4)
                .rotationEffect(.degrees(2))
            DoodleIcon(icon: kind.icon, color: MosaicTheme.ink.opacity(0.72), lineWidth: 2.5)
                .frame(width: size * 0.5, height: size * 0.5)
            Circle().fill(MosaicTheme.persimmon).frame(width: size * 0.08).offset(x: size * 0.31, y: -size * 0.28)
            Circle().fill(MosaicTheme.indigo).frame(width: size * 0.055).offset(x: -size * 0.3, y: size * 0.28)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.11), radius: size * 0.1, y: size * 0.06)
        .accessibilityHidden(true)
    }

    private var variant: OrganicPanelVariant {
        switch kind {
        case .sparkles, .neighborhoodSprout: .leaningLeft
        case .kindNote, .giftRibbon: .leaningRight
        case .helpingHands, .ceramicSun: .softRectangle
        }
    }
}

struct MosaicSectionHeader: View {
    let title: String
    var eyebrow: String?
    var icon: MosaicIcon?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let eyebrow {
                HStack(spacing: 6) {
                    if let icon { DoodleIcon(icon: icon, color: MosaicTheme.persimmon).frame(width: 16, height: 16) }
                    Text(eyebrow.uppercased())
                }
                .font(MosaicTheme.caption(.bold))
                .tracking(0.8)
                .foregroundStyle(MosaicTheme.persimmon)
            }
            Text(title)
                .font(MosaicTheme.display(28, weight: .semibold))
                .foregroundStyle(MosaicTheme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct MosaicProgressRail: View {
    let current: Int
    let total: Int
    var tint: Color = MosaicTheme.indigo

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                OrganicPanelShape(variant: OrganicPanelVariant.allCases[index % OrganicPanelVariant.allCases.count])
                    .fill(index < current ? tint : MosaicTheme.border)
                    .frame(width: index == current - 1 ? 24 : 9, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

extension MissionCategory {
    var mosaicIcon: MosaicIcon {
        switch self {
        case .encouragement: .heart
        case .community: .leaf
        case .giving: .gift
        case .teaching: .bulb
        case .support: .hands
        case .connection: .people
        }
    }
}
