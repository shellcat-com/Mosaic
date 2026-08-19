import SwiftUI

enum MosaicLaunchTiming {
    static let markDuration = 0.96
    static let exitDelay = 1.06
    static let exitDuration = 0.24
    static let totalDuration = exitDelay + exitDuration

    static let reduceMotionHold = 0.35
    static let reduceMotionExitDuration = 0.18
}

/// The native, scalable counterpart to `design/brand/mosaic-logo-master.svg`.
/// Its progress value drives the launch choreography while preserving one source
/// of geometry for static and animated uses.
struct MosaicBrandMark: View, @preconcurrency Animatable {
    var progress: CGFloat = 1
    var includesWordmark = false

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        VStack(spacing: -8) {
            MosaicBrandSymbol(progress: progress)
                .aspectRatio(1, contentMode: .fit)

            if includesWordmark {
                Text("mosaic")
                    .font(MosaicTheme.display(42, weight: .semibold))
                    .tracking(-1.1)
                    .foregroundStyle(MosaicTheme.ink)
                    .opacity(stage(0.82, 1))
                    .offset(y: 4 * (1 - stage(0.82, 1)))
                    .accessibilityHidden(true)
            }
        }
    }

    private func stage(_ start: CGFloat, _ end: CGFloat) -> CGFloat {
        min(max((progress - start) / (end - start), 0), 1)
    }
}

private struct MosaicBrandSymbol: View {
    let progress: CGFloat

    private let indigo = Color(hex: 0x5A47F2)
    private let persimmon = Color(hex: 0xF56E3E)
    private let gold = Color(hex: 0xD6A937)
    private let sage = Color(hex: 0x7D9A83)
    private let sky = Color(hex: 0x7EB7CD)
    private let rose = Color(hex: 0xE4A6B4)
    private let porcelain = Color(hex: 0xFFFDF8)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width, proxy.size.height) / 1024

            ZStack {
                bottomTile(x: 132, fill: sage, start: 0.00)
                bottomTile(x: 393, fill: sky, start: 0.07)
                bottomTile(x: 654, fill: rose, start: 0.14)

                topTile(x: 132, y: 236, height: 252, fill: rose, start: 0.24)
                topTile(x: 393, y: 196, height: 292, fill: gold, start: 0.31)
                topTile(x: 654, y: 236, height: 252, fill: persimmon, start: 0.38)

                CrayonGrain()
                    .foregroundStyle(porcelain.opacity(0.22))
                    .mask(AllTileMask())
                    .opacity(stage(0.18, 0.62))

                sunrise
                    .mask(TopTileMask())

                people

                RevealSparkShape()
                    .fill(porcelain)
                    .overlay {
                        RevealSparkShape()
                            .stroke(indigo, style: StrokeStyle(lineWidth: 10, lineJoin: .round))
                    }
                    .frame(width: 60, height: 60)
                    .position(x: 512, y: 481)
                    .scaleEffect(0.55 + 0.45 * stage(0.78, 0.94))
                    .opacity(stage(0.78, 0.94))
                    .overlay {
                        Circle()
                            .fill(Color(hex: 0xF5B934))
                            .frame(width: 10, height: 10)
                            .position(x: 512, y: 481)
                            .opacity(stage(0.86, 0.97))
                    }
            }
            .frame(width: 1024, height: 1024)
            .scaleEffect(scale)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    private func bottomTile(x: CGFloat, fill: Color, start: CGFloat) -> some View {
        let amount = stage(start, start + 0.32)
        return BrandTile(fill: fill)
            .frame(width: 238, height: 252)
            .position(x: x + 119, y: 636)
            .offset(y: 92 * (1 - amount))
            .opacity(amount)
    }

    private func topTile(
        x: CGFloat,
        y: CGFloat,
        height: CGFloat,
        fill: Color,
        start: CGFloat
    ) -> some View {
        let amount = stage(start, start + 0.30)
        return BrandTile(fill: fill)
            .frame(width: 238, height: height)
            .position(x: x + 119, y: y + height / 2)
            .offset(y: -74 * (1 - amount))
            .opacity(amount)
    }

    private var sunrise: some View {
        ZStack {
            SunriseFillShape()
                .fill(Color(hex: 0xF5B934))
                .opacity(stage(0.52, 0.72))

            SunriseArcShape()
                .trim(from: 0, to: stage(0.50, 0.80))
                .stroke(indigo, style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))

            SunriseRaysShape()
                .trim(from: 0, to: stage(0.72, 0.92))
                .stroke(indigo, style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
        }
    }

    private var people: some View {
        ZStack {
            ForEach(Array([251.0, 512.0, 773.0].enumerated()), id: \.offset) { index, x in
                PersonGlyphShape()
                    .trim(from: 0, to: stage(CGFloat(index) * 0.07 + 0.08, CGFloat(index) * 0.07 + 0.46))
                    .stroke(indigo, style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
                    .frame(width: 140, height: 178)
                    .position(x: x, y: 666)
            }
        }
    }

    private func stage(_ start: CGFloat, _ end: CGFloat) -> CGFloat {
        min(max((progress - start) / (end - start), 0), 1)
    }
}

private struct BrandTile: View {
    let fill: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(
                        Color(hex: 0x5A47F2),
                        style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round)
                    )
            }
    }
}

private struct TopTileMask: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: CGRect(x: 132, y: 236, width: 238, height: 252), cornerSize: CGSize(width: 34, height: 34))
        path.addRoundedRect(in: CGRect(x: 393, y: 196, width: 238, height: 292), cornerSize: CGSize(width: 34, height: 34))
        path.addRoundedRect(in: CGRect(x: 654, y: 236, width: 238, height: 252), cornerSize: CGSize(width: 34, height: 34))
        return path
    }
}

private struct AllTileMask: Shape {
    func path(in rect: CGRect) -> Path {
        var path = TopTileMask().path(in: rect)
        for x in [132.0, 393.0, 654.0] {
            path.addRoundedRect(
                in: CGRect(x: x, y: 510, width: 238, height: 252),
                cornerSize: CGSize(width: 34, height: 34)
            )
        }
        return path
    }
}

private struct SunriseFillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 286, y: 497))
        path.addArc(
            center: CGPoint(x: 512, y: 497), radius: 226,
            startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false
        )
        path.addLine(to: CGPoint(x: 286, y: 497))
        path.closeSubpath()
        return path
    }
}

private struct SunriseArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: 512, y: 497), radius: 226,
            startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false
        )
        return path
    }
}

private struct SunriseRaysShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let rays = [
            (CGPoint(x: 512, y: 252), CGPoint(x: 512, y: 306)),
            (CGPoint(x: 414, y: 278), CGPoint(x: 441, y: 326)),
            (CGPoint(x: 610, y: 278), CGPoint(x: 583, y: 326)),
            (CGPoint(x: 340, y: 350), CGPoint(x: 390, y: 378)),
            (CGPoint(x: 684, y: 350), CGPoint(x: 634, y: 378))
        ]
        for ray in rays {
            path.move(to: ray.0)
            path.addLine(to: ray.1)
        }
        return path
    }
}

private struct PersonGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 31, y: 0, width: 78, height: 78))
        path.move(to: CGPoint(x: 0, y: 178))
        path.addCurve(
            to: CGPoint(x: 140, y: 178),
            control1: CGPoint(x: 6, y: 92),
            control2: CGPoint(x: 134, y: 92)
        )
        return path
    }
}

private struct RevealSparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.midX + 6, y: rect.midY - 10),
            control2: CGPoint(x: rect.midX + 10, y: rect.midY - 6)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.midX + 10, y: rect.midY + 6),
            control2: CGPoint(x: rect.midX + 6, y: rect.midY + 10)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control1: CGPoint(x: rect.midX - 6, y: rect.midY + 10),
            control2: CGPoint(x: rect.midX - 10, y: rect.midY + 6)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.midX - 10, y: rect.midY - 6),
            control2: CGPoint(x: rect.midX - 6, y: rect.midY - 10)
        )
        path.closeSubpath()
        return path
    }
}

private struct CrayonGrain: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<82 {
            let x = CGFloat((index * 73) % 760) + 132
            let y = CGFloat((index * 47) % 550) + 200
            let length = CGFloat(10 + (index * 11) % 24)
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + length, y: y - length * 0.20))
        }
        return path.strokedPath(StrokeStyle(lineWidth: 3.2, lineCap: .round))
    }
}

struct MosaicLaunchOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinished: () -> Void

    @State private var markProgress: CGFloat = 0
    @State private var overlayOpacity = 1.0

    var body: some View {
        ZStack {
            Color(hex: 0xFBF8F1).ignoresSafeArea()

            MosaicBrandMark(progress: markProgress, includesWordmark: true)
                .frame(width: 286, height: 344)
        }
        .opacity(overlayOpacity)
        .accessibilityHidden(true)
        .task {
            if reduceMotion {
                markProgress = 1
                try? await Task.sleep(for: .seconds(MosaicLaunchTiming.reduceMotionHold))
                withAnimation(.easeOut(duration: MosaicLaunchTiming.reduceMotionExitDuration)) {
                    overlayOpacity = 0
                }
                try? await Task.sleep(for: .seconds(MosaicLaunchTiming.reduceMotionExitDuration))
            } else {
                withAnimation(.easeOut(duration: MosaicLaunchTiming.markDuration)) {
                    markProgress = 1
                }
                try? await Task.sleep(for: .seconds(MosaicLaunchTiming.exitDelay))
                withAnimation(.easeOut(duration: MosaicLaunchTiming.exitDuration)) {
                    overlayOpacity = 0
                }
                try? await Task.sleep(for: .seconds(MosaicLaunchTiming.exitDuration))
            }

            guard !Task.isCancelled else { return }
            onFinished()
        }
    }
}
