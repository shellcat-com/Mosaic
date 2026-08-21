import SwiftUI

struct KinderArtworkView: View {
    let selection: ThemeSelection
    var phase: KinderArtworkPhase = .thumbnail
    var revealProgress: Double = 1
    var cornerRadius: CGFloat = 26
    var showsTitle = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var theme: KinderTheme { selection.theme }
    private var palette: ArtworkPalette { ArtworkPalette(theme: theme, paletteID: selection.paletteID) }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion || freezeMarketingArtwork || !isAnimatedPhase)) { timeline in
                let time = freezeMarketingArtwork ? 0 : timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    OrganicPanelShape(variant: .softRectangle)
                        .fill(backgroundGradient)

                    HandmadePaperTexture(
                        seed: theme.seed,
                        material: theme.material,
                        ink: palette.ink.opacity(reduceTransparency ? 0.06 : 0.13)
                    )

                    composition(in: geometry.size, time: time)
                        .opacity(phase == .sealed ? 0.46 : 1)
                        .blur(radius: phase == .sealed ? 2.2 : 0)

                    if phase == .sealed || phase == .active {
                        SealedCeramicVeil(
                            seed: selection.seed,
                            tint: palette.paper,
                            ink: palette.ink,
                            progress: phase == .active ? 0.34 : 0.16
                        )
                    }

                    glaze

                    if showsTitle {
                        VStack {
                            Spacer()
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(theme.collection.title.uppercased())
                                        .font(.system(size: 8, weight: .bold, design: .rounded))
                                        .tracking(0.9)
                                    Text(theme.name)
                                        .font(MosaicTheme.display(20, weight: .semibold))
                                }
                                Spacer()
                            }
                            .foregroundStyle(palette.ink)
                            .padding(16)
                            .background(
                                LinearGradient(
                                    colors: [palette.paper.opacity(0), palette.paper.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                }
                .mask {
                    if phase == .reveal {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .frame(height: geometry.size.height * revealProgress.clamped(to: 0...1))
                        }
                    } else {
                        Rectangle()
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.56), lineWidth: 1)
        }
        .shadow(color: palette.shadow.opacity(phase == .thumbnail ? 0.2 : 0.28), radius: 16, y: 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.accessibilityDescription)
    }

    private var isAnimatedPhase: Bool {
        phase == .invitation || phase == .reveal
    }

    private var freezeMarketingArtwork: Bool {
#if DEBUG
        MarketingPreviewScene.current != nil
#else
        false
#endif
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [palette.background, palette.paper, palette.secondary.opacity(0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func composition(in size: CGSize, time: TimeInterval) -> some View {
        let points = layoutPoints(for: theme.composition, size: size)
        let motion: CGSize = (reduceMotion || freezeMarketingArtwork) ? .zero : motionOffset(time: time, size: size)

        ZStack {
            HandPaintedBackdrop(
                composition: theme.composition,
                seed: theme.seed,
                primary: palette.primary.opacity(0.27),
                secondary: palette.secondary.opacity(0.22),
                ink: palette.ink.opacity(0.16)
            )

            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                let isHero = index == points.count / 2
                ThemeCeramicMark(
                    symbol: isHero ? theme.heroSymbol : theme.accentSymbol,
                    fill: index.isMultiple(of: 2) ? palette.primary : palette.secondary,
                    ink: palette.ink,
                    material: theme.material,
                    seed: theme.seed + index * 37,
                    isHero: isHero
                )
                .frame(width: point.scale * size.width, height: point.scale * size.width)
                .rotationEffect(.degrees(point.rotation))
                .position(
                    x: point.x * size.width + motion.width * point.motion,
                    y: point.y * size.height + motion.height * point.motion
                )
            }

            ThemeInkFlourish(
                composition: theme.composition,
                ink: palette.ink.opacity(0.34),
                seed: theme.seed
            )
            .padding(size.width * 0.05)
        }
    }

    private var glaze: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.42), .clear, palette.primary.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.25), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 190
            )
        }
        .blendMode(.softLight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func motionOffset(time: TimeInterval, size: CGSize) -> CGSize {
        let wave = sin(time * 0.8 + Double(theme.seed % 11))
        let slow = cos(time * 0.47 + Double(theme.seed % 7))
        switch theme.revealMotion {
        case .bloom: return CGSize(width: 0, height: CGFloat(wave) * size.height * 0.008)
        case .ripple: return CGSize(width: CGFloat(wave) * size.width * 0.009, height: 0)
        case .rise: return CGSize(width: 0, height: CGFloat(slow) * size.height * 0.012)
        case .stitch: return CGSize(width: CGFloat(slow) * 2, height: CGFloat(wave) * 2)
        case .scatter: return CGSize(width: CGFloat(wave) * 3, height: CGFloat(slow) * 3)
        case .glow: return .zero
        case .unfold: return CGSize(width: CGFloat(wave) * 2, height: 0)
        case .drift: return CGSize(width: CGFloat(slow) * size.width * 0.012, height: CGFloat(wave) * 2)
        case .parade: return CGSize(width: CGFloat(wave) * size.width * 0.014, height: 0)
        case .twinkle: return CGSize(width: CGFloat(wave), height: CGFloat(slow))
        }
    }
}

private struct ArtworkPalette {
    let background: Color
    let paper: Color
    let primary: Color
    let secondary: Color
    let ink: Color
    let shadow: Color

    init(theme: KinderTheme, paletteID: KinderThemePaletteID) {
        let hex = theme.signatureHex
        switch paletteID {
        case .signature:
            background = Color(hex: hex[2]).opacity(0.46)
            paper = Color(hex: 0xFFF9EF)
            primary = Color(hex: hex[0])
            secondary = Color(hex: hex[1])
            ink = Color(hex: 0x302A27)
            shadow = Color(hex: 0x4B392F)
        case .soft:
            background = Color(hex: 0xF4EEE6)
            paper = Color(hex: 0xFFFDF8)
            primary = Color(hex: hex[0]).opacity(0.72)
            secondary = Color(hex: hex[1]).opacity(0.68)
            ink = Color(hex: 0x4A433D)
            shadow = Color(hex: 0x8D7B6C)
        case .kilnNight:
            background = Color(hex: 0x17131C)
            paper = Color(hex: 0x282128)
            primary = Color(hex: hex[0])
            secondary = Color(hex: hex[1])
            ink = Color(hex: 0xFFF2DD)
            shadow = Color.black
        }
    }
}

private struct LayoutPoint {
    let x: CGFloat
    let y: CGFloat
    let scale: CGFloat
    let rotation: Double
    let motion: CGFloat
}

private func layoutPoints(for composition: KinderComposition, size: CGSize) -> [LayoutPoint] {
    switch composition {
    case .bouquet:
        [p(0.22, 0.66, 0.25, -12), p(0.34, 0.43, 0.22, 8), p(0.52, 0.55, 0.34, -3, 0.4), p(0.70, 0.38, 0.21, 12), p(0.80, 0.68, 0.24, -7)]
    case .orbit:
        [p(0.20, 0.52, 0.18, -14), p(0.34, 0.27, 0.16, 9), p(0.52, 0.50, 0.36, -2, 0.5), p(0.72, 0.30, 0.17, 14), p(0.82, 0.63, 0.19, -9), p(0.43, 0.76, 0.15, 7)]
    case .landscape:
        [p(0.18, 0.70, 0.18, -7), p(0.35, 0.60, 0.20, 5), p(0.55, 0.52, 0.35, -2, 0.3), p(0.76, 0.64, 0.22, 8), p(0.82, 0.29, 0.16, -11)]
    case .quilt:
        [p(0.24, 0.32, 0.22, -3), p(0.51, 0.30, 0.23, 4), p(0.76, 0.33, 0.21, -5), p(0.26, 0.68, 0.22, 5), p(0.52, 0.64, 0.30, -2, 0.2), p(0.78, 0.69, 0.22, 4)]
    case .arch:
        [p(0.20, 0.65, 0.20, -12), p(0.28, 0.38, 0.18, 8), p(0.50, 0.23, 0.23, -2), p(0.52, 0.57, 0.34, 1, 0.4), p(0.72, 0.38, 0.18, -8), p(0.82, 0.65, 0.20, 12)]
    case .cascade:
        [p(0.22, 0.22, 0.18, -9), p(0.37, 0.37, 0.21, 8), p(0.52, 0.52, 0.34, -2, 0.4), p(0.68, 0.67, 0.20, -8), p(0.82, 0.80, 0.17, 11)]
    case .stillLife:
        [p(0.26, 0.62, 0.22, -8), p(0.43, 0.55, 0.23, 5), p(0.59, 0.48, 0.35, -2, 0.3), p(0.77, 0.63, 0.20, 9), p(0.66, 0.27, 0.16, -6)]
    case .constellation:
        [p(0.18, 0.27, 0.14, -5), p(0.37, 0.38, 0.17, 8), p(0.54, 0.52, 0.31, 0, 0.5), p(0.76, 0.29, 0.15, -9), p(0.82, 0.68, 0.18, 5), p(0.30, 0.78, 0.13, 7)]
    case .procession:
        [p(0.12, 0.63, 0.17, -9), p(0.30, 0.55, 0.20, 5), p(0.51, 0.51, 0.32, -2, 0.5), p(0.70, 0.56, 0.20, -5), p(0.88, 0.64, 0.17, 9)]
    case .vignette:
        [p(0.27, 0.61, 0.20, -8), p(0.50, 0.51, 0.40, 0, 0.35), p(0.74, 0.62, 0.19, 8), p(0.69, 0.27, 0.15, -5)]
    }
}

private func p(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat, _ rotation: Double, _ motion: CGFloat = 0.16) -> LayoutPoint {
    LayoutPoint(x: x, y: y, scale: scale, rotation: rotation, motion: motion)
}

private struct ThemeCeramicMark: View {
    let symbol: String
    let fill: Color
    let ink: Color
    let material: KinderMaterial
    let seed: Int
    let isHero: Bool

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                OrganicPanelShape(variant: isHero ? .leaningLeft : .softRectangle)
                    .fill(
                        LinearGradient(
                            colors: [fill.opacity(0.98), fill.opacity(0.72), fill.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        OrganicPanelShape(variant: isHero ? .leaningLeft : .softRectangle, inset: side * 0.045)
                            .stroke(Color.white.opacity(0.48), lineWidth: max(0.7, side * 0.015))
                    }
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(ink.opacity(0.7))
                    .padding(side * (isHero ? 0.23 : 0.26))
                    .shadow(color: Color.white.opacity(0.34), radius: 0, y: 1)
                CeramicMarkTexture(material: material, seed: seed, ink: ink.opacity(0.12))
                    .clipShape(OrganicPanelShape(variant: isHero ? .leaningLeft : .softRectangle))
            }
            .shadow(color: ink.opacity(0.18), radius: side * 0.08, y: side * 0.06)
        }
    }
}

private struct HandmadePaperTexture: View {
    let seed: Int
    let material: KinderMaterial
    let ink: Color

    var body: some View {
        Canvas { context, size in
            let count = material == .gouachePaper || material == .chalkWash ? 110 : 72
            for index in 0..<count {
                let x = pseudo(seed + index * 43, modulus: 997) * size.width
                let y = pseudo(seed + index * 71, modulus: 991) * size.height
                let radius = 0.4 + pseudo(seed + index * 17, modulus: 37) * 1.2
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius * 0.74)), with: .color(ink))
            }
        }
        .blendMode(.multiply)
        .accessibilityHidden(true)
    }
}

private struct CeramicMarkTexture: View {
    let material: KinderMaterial
    let seed: Int
    let ink: Color

    var body: some View {
        Canvas { context, size in
            switch material {
            case .stitchedFabric:
                for index in 0..<7 {
                    var path = Path()
                    path.move(to: CGPoint(x: size.width * 0.14, y: size.height * (0.16 + Double(index) * 0.11)))
                    path.addLine(to: CGPoint(x: size.width * 0.86, y: size.height * (0.14 + Double(index) * 0.11)))
                    context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                }
            case .carvedSlip, .inkedPorcelain:
                for index in 0..<5 {
                    let inset = CGFloat(index + 1) * min(size.width, size.height) * 0.065
                    context.stroke(Path(ellipseIn: CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)), with: .color(ink), lineWidth: 0.7)
                }
            default:
                for index in 0..<22 {
                    let x = pseudo(seed + index * 19, modulus: 97) * size.width
                    let y = pseudo(seed + index * 29, modulus: 89) * size.height
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(ink))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct HandPaintedBackdrop: View {
    let composition: KinderComposition
    let seed: Int
    let primary: Color
    let secondary: Color
    let ink: Color

    var body: some View {
        Canvas { context, size in
            for index in 0..<7 {
                let width = size.width * (0.24 + pseudo(seed + index * 31, modulus: 43) * 0.28)
                let height = size.height * (0.14 + pseudo(seed + index * 47, modulus: 41) * 0.22)
                let x = pseudo(seed + index * 67, modulus: 101) * max(1, size.width - width)
                let y = pseudo(seed + index * 83, modulus: 103) * max(1, size.height - height)
                let rect = CGRect(x: x, y: y, width: width, height: height)
                context.fill(OrganicPanelShape(variant: index.isMultiple(of: 2) ? .leaningLeft : .leaningRight).path(in: rect), with: .color(index.isMultiple(of: 2) ? primary : secondary))
            }

            if composition == .landscape || composition == .procession {
                var ground = Path()
                ground.move(to: CGPoint(x: 0, y: size.height * 0.78))
                ground.addCurve(to: CGPoint(x: size.width, y: size.height * 0.73), control1: CGPoint(x: size.width * 0.3, y: size.height * 0.68), control2: CGPoint(x: size.width * 0.68, y: size.height * 0.84))
                context.stroke(ground, with: .color(ink), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [4, 7]))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ThemeInkFlourish: View {
    let composition: KinderComposition
    let ink: Color
    let seed: Int

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.78))
            path.addCurve(
                to: CGPoint(x: size.width * 0.92, y: size.height * 0.26),
                control1: CGPoint(x: size.width * 0.27, y: size.height * (composition == .cascade ? 0.18 : 0.88)),
                control2: CGPoint(x: size.width * 0.68, y: size.height * (composition == .arch ? 0.06 : 0.58))
            )
            context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2, 8]))
        }
        .accessibilityHidden(true)
    }
}

private struct SealedCeramicVeil: View {
    let seed: Int
    let tint: Color
    let ink: Color
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let columns = 5
            let rows = 4
            let spacing: CGFloat = 4
            let width = (geometry.size.width - CGFloat(columns + 1) * spacing) / CGFloat(columns)
            let height = (geometry.size.height - CGFloat(rows + 1) * spacing) / CGFloat(rows)
            ZStack {
                ForEach(0..<(columns * rows), id: \.self) { index in
                    if Double(index) / Double(columns * rows) >= progress {
                        OrganicPanelShape(variant: index.isMultiple(of: 3) ? .leaningLeft : .softRectangle)
                            .fill(tint.opacity(0.88))
                            .overlay {
                                OrganicPanelShape(variant: index.isMultiple(of: 3) ? .leaningLeft : .softRectangle)
                                    .stroke(ink.opacity(0.12), lineWidth: 0.7)
                            }
                            .frame(width: width, height: height)
                            .position(
                                x: spacing + width / 2 + CGFloat(index % columns) * (width + spacing),
                                y: spacing + height / 2 + CGFloat(index / columns) * (height + spacing)
                            )
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private func pseudo(_ value: Int, modulus: Int) -> CGFloat {
    CGFloat(abs(value &* 1_103_515_245 &+ 12_345) % modulus) / CGFloat(modulus)
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
