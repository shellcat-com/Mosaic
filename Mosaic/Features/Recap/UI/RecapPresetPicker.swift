import SwiftUI

struct RecapPresetPicker: View {
    let selected: RecapPreset
    let select: (RecapPreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(RecapPresetCatalog.all) { preset in
                    Button { select(preset) } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            RecapPresetThumbnail(preset: preset, isSelected: selected.id == preset.id)
                            .frame(width: 154, height: 205)
                            Text(preset.name).font(MosaicTheme.display(18, weight: .semibold)).foregroundStyle(MosaicTheme.ink)
                            Text("\(Int(preset.nominalMontageDuration)) sec montage")
                                .font(MosaicTheme.caption()).foregroundStyle(MosaicTheme.muted)
                        }
                        .padding(10)
                        .background(selected.id == preset.id ? MosaicTheme.indigo.opacity(0.1) : MosaicTheme.paper,
                                    in: OrganicPanelShape(variant: .softRectangle))
                        .overlay { OrganicPanelShape(variant: .softRectangle).stroke(selected.id == preset.id ? MosaicTheme.indigo : MosaicTheme.border, lineWidth: selected.id == preset.id ? 2 : 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.visualStyle == .standard ? preset.name : "New template, \(preset.name)")
                    .accessibilityAddTraits(selected.id == preset.id ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2).padding(.vertical, 6)
        }
    }

}

private struct RecapPresetThumbnail: View {
    let preset: RecapPreset
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch preset.visualStyle {
                case .standard: standardPreview
                case .porcelainPrint: porcelainPreview
                case .kilnTape: tapePreview
                case .pocketKiln: pocketPreview
                }
                if preset.visualStyle != .standard {
                    Text("NEW")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(MosaicTheme.persimmon, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(8)
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(9)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private var standardPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(gradient(for: preset))
            Image(systemName: icon(for: preset)).font(.system(size: 32)).foregroundStyle(.white.opacity(0.9))
        }
    }

    private var porcelainPreview: some View {
        ZStack {
            Color(hex: 0xFBF8F1)
            RoundedRectangle(cornerRadius: 7)
                .fill(.white)
                .shadow(color: .black.opacity(0.16), radius: 7, y: 4)
                .padding(.horizontal, 17).padding(.vertical, 12)
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [MosaicTheme.clay, MosaicTheme.rose.opacity(0.72), MosaicTheme.sky],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    VStack(spacing: 2) {
                        Text("MOSAIC").font(.system(size: 7, weight: .bold, design: .rounded)).tracking(1)
                        Text("Memories").font(MosaicTheme.display(19, weight: .semibold))
                    }.foregroundStyle(.white)
                }
                .frame(height: 137)
                HStack(spacing: 4) {
                    Diamond().fill(MosaicTheme.indigo).frame(width: 6, height: 6)
                    Text("A MOSAIC STORY").font(.system(size: 6, weight: .bold, design: .monospaced))
                }.foregroundStyle(MosaicTheme.ink.opacity(0.7))
            }
            .padding(.horizontal, 23).padding(.vertical, 19)
        }
    }

    private var tapePreview: some View {
        ZStack {
            Color.black
            RoundedRectangle(cornerRadius: 13).fill(Color(hex: 0x1B1B1D)).padding(6)
            VStack(spacing: 7) {
                HStack {
                    Text("PLAY // 01")
                    Spacer()
                    Text("MOSAIC")
                }
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.68))
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [Color(hex: 0x0E1112), MosaicTheme.indigo.opacity(0.7), MosaicTheme.persimmon.opacity(0.68)],
                                             startPoint: .top, endPoint: .bottomTrailing))
                    VStack(spacing: 2) {
                        Text("2026").font(MosaicTheme.display(30))
                        Text("KILN TAPE").font(.system(size: 6, weight: .bold, design: .monospaced)).tracking(1)
                    }.foregroundStyle(Color(hex: 0xF7F1E7))
                }
                HStack {
                    Image(systemName: "play.fill").font(.system(size: 7)).foregroundStyle(MosaicTheme.persimmon)
                    Text("MOSAIC // STEREO").font(.system(size: 5, weight: .bold, design: .monospaced))
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle().fill(index < 3 ? MosaicTheme.persimmon : .white.opacity(0.18)).frame(width: 4, height: 4)
                        }
                    }
                }.foregroundStyle(.white.opacity(0.6))
            }
            .padding(14)
        }
    }

    private var pocketPreview: some View {
        ZStack {
            Color(hex: 0xFBF8F1)
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(hex: 0x292C2A))
                .padding(.horizontal, 13).padding(.vertical, 10)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 5)
            VStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [Color(hex: 0x111211), MosaicTheme.sage.opacity(0.75), MosaicTheme.clay],
                                             startPoint: .top, endPoint: .bottomTrailing))
                    ViewfinderCorners().stroke(.white.opacity(0.72), lineWidth: 1.2).padding(28)
                    VStack {
                        HStack(spacing: 3) {
                            Circle().fill(MosaicTheme.persimmon).frame(width: 5, height: 5)
                            Text("REC").font(.system(size: 6, weight: .bold, design: .monospaced))
                            Spacer()
                        }
                        Spacer()
                        Text("POCKET KILN").font(.system(size: 6, weight: .bold, design: .monospaced)).tracking(0.8)
                    }.padding(8).foregroundStyle(.white.opacity(0.85))
                }
                .frame(height: 132)
                HStack(spacing: 7) {
                    Circle().fill(.white.opacity(0.18)).frame(width: 17, height: 17)
                    Circle().fill(.white.opacity(0.18)).frame(width: 17, height: 17)
                    Spacer()
                    Circle().fill(.white.opacity(0.22)).frame(width: 31, height: 31)
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 22).padding(.vertical, 18)
        }
    }

    private func gradient(for preset: RecapPreset) -> LinearGradient {
        let colors: [Color] = switch preset.grade {
        case .coolMonochrome: [.gray, .blue.opacity(0.55)]
        case .mutedOlive: [MosaicTheme.sage, MosaicTheme.clay]
        case .softRose: [MosaicTheme.rose, .white]
        case .tealNight: [.teal.opacity(0.7), .black]
        case .fadedAmber: [MosaicTheme.clay, MosaicTheme.gold]
        case .goldenHour: [MosaicTheme.gold, MosaicTheme.persimmon.opacity(0.65)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func icon(for preset: RecapPreset) -> String {
        switch preset.layout {
        case .fullBleed: "photo.fill"
        case .triptych: "rectangle.split.3x1.fill"
        case .ceramicFilmstrip: "film.stack.fill"
        case .stackedPrints: "photo.stack.fill"
        }
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) * 0.24
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm)); path.addLine(to: CGPoint(x: rect.minX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - arm)); path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        return path
    }
}
