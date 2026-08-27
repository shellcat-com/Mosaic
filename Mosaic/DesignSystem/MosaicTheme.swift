import CoreText
import SwiftUI
import UIKit

enum MosaicTheme {
    static let porcelain = dynamic(light: 0xFFFCF5, dark: 0x181614)
    static let canvas = dynamic(light: 0xF4EEE4, dark: 0x211E1B)
    static let paper = dynamic(light: 0xFFFCF6, dark: 0x2B2723)
    static let raisedPaper = dynamic(light: 0xFFFFFF, dark: 0x35302B)
    static let ink = dynamic(light: 0x2D2925, dark: 0xFFF5E8)
    static let muted = dynamic(light: 0x685F57, dark: 0xC5B9AA)
    static let border = dynamic(light: 0xD9CDBC, dark: 0x554D45)
    static let indigo = Color(hex: 0x315F6B)
    static let deepGlaze = Color(hex: 0x214A55)
    /// Contrast-safe teal for text, symbols, links, focus rings, and progress.
    /// Keep `indigo` and `deepGlaze` for filled material surfaces.
    static let accentForeground = dynamic(light: 0x214A55, dark: 0x78A9B5)
    static let persimmon = Color(hex: 0xC9633F)
    static let sage = Color(hex: 0x718D78)
    static let sky = Color(hex: 0x78A9B5)
    static let rose = Color(hex: 0xC98F92)
    static let clay = Color(hex: 0xAD765B)
    static let gold = Color(hex: 0xC49A3C)
    static let claySurface = dynamic(light: 0xEDE0D1, dark: 0x46372F)
    static let unglazedCeramic = dynamic(light: 0xFFFCF5, dark: 0xD8CEC0)
    static let warmShadow = Color(hex: 0x5C4435).opacity(0.14)
    static let glazePalette = [deepGlaze, persimmon, sage, sky, rose, clay, gold]
    static let editorialScrim = Color.black.opacity(0.32)

    static let minimumHitTarget: CGFloat = 44
    static let artworkCornerRadius: CGFloat = 28
    static let sceneTransitionDuration = 0.42

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let screen: CGFloat = 20
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let large: CGFloat = 20
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = MosaicFontRegistrar.boldPostScriptName
        case .semibold: name = MosaicFontRegistrar.semiboldPostScriptName
        default: name = MosaicFontRegistrar.regularPostScriptName
        }
        return .custom(name, size: size, relativeTo: .title)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(.body, design: .rounded, weight: weight)
    }

    static func caption(_ weight: Font.Weight = .regular) -> Font {
        .system(.caption, design: .rounded, weight: weight)
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum MosaicFontRegistrar {
    static let regularPostScriptName = "Fraunces72ptSoft-Regular"
    static let semiboldPostScriptName = "Fraunces72ptSoft-SemiBold"
    static let boldPostScriptName = "Fraunces72ptSoft-Bold"
    static let resourceNames = [regularPostScriptName, semiboldPostScriptName, boldPostScriptName]

    static func register() {
        for name in resourceNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

struct PorcelainBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(MosaicTheme.canvas.ignoresSafeArea())
    }
}

extension View {
    func porcelainBackground() -> some View {
        modifier(PorcelainBackground())
    }

    func porcelainCard() -> some View {
        padding(16)
            .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: MosaicTheme.Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MosaicTheme.Radius.large, style: .continuous)
                    .stroke(MosaicTheme.border, lineWidth: 1)
            }
            .shadow(color: MosaicTheme.warmShadow, radius: 8, y: 3)
    }
}
