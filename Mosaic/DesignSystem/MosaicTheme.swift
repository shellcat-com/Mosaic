import CoreText
import SwiftUI
import UIKit

enum MosaicTheme {
    // MARK: Semantic palette

    static let canvas = dynamic(light: 0xFBF8F1, dark: 0x141210)
    static let paper = dynamic(light: 0xFFFDF8, dark: 0x201D19)
    static let raisedPaper = dynamic(light: 0xFFFFFF, dark: 0x29251F)
    static let ink = dynamic(light: 0x25221F, dark: 0xF7F1E7)
    static let muted = dynamic(light: 0x76706A, dark: 0xB8B0A6)
    static let border = dynamic(light: 0xD9D0C3, dark: 0x3D3831)
    static let claySurface = dynamic(light: 0xE8DDCC, dark: 0x332B23)

    static let indigo = Color(hex: 0x5A47F2)
    static let persimmon = Color(hex: 0xF56E3E)
    static let sage = Color(hex: 0x7D9A83)
    static let sky = Color(hex: 0x7EB7CD)
    static let rose = Color(hex: 0xE4A6B4)
    static let clay = Color(hex: 0xB89E80)
    static let gold = Color(hex: 0xD6A937)

    // Compatibility aliases used by the existing artwork scenes.
    static let porcelain = canvas
    static let editorialScrim = dynamic(light: 0xFBF5E8, dark: 0x211B16)

    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
        static let xLarge: CGFloat = 30
        static let screen: CGFloat = 20
    }

    enum Radius {
        static let small: CGFloat = 14
        static let medium: CGFloat = 20
        static let large: CGFloat = 28
    }

    static let artworkCornerRadius: CGFloat = Radius.large
    static let sceneTransitionDuration = 0.45
    static let minimumHitTarget: CGFloat = 44

    // MARK: Typography

    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:
            name = MosaicFontRegistrar.boldPostScriptName
        case .medium, .semibold:
            name = MosaicFontRegistrar.semiboldPostScriptName
        default:
            name = MosaicFontRegistrar.regularPostScriptName
        }

        return .custom(name, size: size, relativeTo: textStyle(for: size))
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(.body, design: .rounded, weight: weight)
    }

    static func caption(_ weight: Font.Weight = .medium) -> Font {
        .system(.caption, design: .rounded, weight: weight)
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 36...: return .largeTitle
        case 28...: return .title
        case 22...: return .title2
        case 18...: return .title3
        default: return .body
        }
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum MosaicFontRegistrar {
    static let regularPostScriptName = "Fraunces72ptSoft-Regular"
    static let semiboldPostScriptName = "Fraunces72ptSoft-SemiBold"
    static let boldPostScriptName = "Fraunces72ptSoft-Bold"

    static let resourceNames = [
        "Fraunces72ptSoft-Regular",
        "Fraunces72ptSoft-SemiBold",
        "Fraunces72ptSoft-Bold"
    ]

    static func register() {
        for resourceName in resourceNames {
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

struct PorcelainBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .foregroundStyle(MosaicTheme.ink)
            .background {
                ZStack {
                    MosaicTheme.canvas.ignoresSafeArea()
                    if !reduceTransparency {
                        Canvas { context, size in
                            for index in 0..<64 {
                                let x = CGFloat((index * 47) % 101) / 101 * size.width
                                let y = CGFloat((index * 71) % 103) / 103 * size.height
                                let diameter = index.isMultiple(of: 4) ? 1.5 : 0.9
                                context.fill(
                                    Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                                    with: .color(MosaicTheme.clay.opacity(0.1))
                                )
                            }
                        }
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                    }
                }
            }
    }
}

extension View {
    func porcelainBackground() -> some View { modifier(PorcelainBackground()) }

    func porcelainCard() -> some View {
        padding(MosaicTheme.Spacing.medium)
            .background(MosaicTheme.paper, in: OrganicPanelShape(variant: .softRectangle))
            .overlay {
                OrganicPanelShape(variant: .softRectangle)
                    .stroke(MosaicTheme.border.opacity(0.72), lineWidth: 1)
            }
            .overlay {
                OrganicPanelShape(variant: .softRectangle, inset: 3)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(0.09), radius: 15, y: 8)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = MosaicTheme.indigo

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: MosaicTheme.minimumHitTarget)
            .padding(.vertical, 7)
            .padding(.horizontal, 18)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1), in: HandDrawnCapsule(inset: 0))
            .overlay {
                HandDrawnCapsule(inset: 3)
                    .stroke(Color.white.opacity(0.42), lineWidth: 1.1)
            }
            .shadow(color: color.opacity(configuration.isPressed ? 0.08 : 0.25), radius: 12, y: 7)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = MosaicTheme.indigo

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: MosaicTheme.minimumHitTarget)
            .padding(.vertical, 6)
            .padding(.horizontal, 18)
            .background(MosaicTheme.paper.opacity(configuration.isPressed ? 0.75 : 1), in: HandDrawnCapsule(inset: 0))
            .overlay { HandDrawnCapsule(inset: 1).stroke(color.opacity(0.65), lineWidth: 1.5) }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct EditorialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonStyle(color: MosaicTheme.indigo).makeBody(configuration: configuration)
    }
}

/// A deliberately imperfect capsule used for the hand-inked interaction language.
struct HandDrawnCapsule: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let curve = min(r.height * 0.52, 29)
        var path = Path()
        path.move(to: CGPoint(x: r.minX + curve, y: r.minY + 1.5))
        path.addCurve(to: CGPoint(x: r.maxX - curve * 0.82, y: r.minY + 0.8), control1: CGPoint(x: r.width * 0.34, y: r.minY - 1.2), control2: CGPoint(x: r.width * 0.68, y: r.minY + 2.4))
        path.addCurve(to: CGPoint(x: r.maxX - 1.2, y: r.midY + 1), control1: CGPoint(x: r.maxX - curve * 0.24, y: r.minY + 1), control2: CGPoint(x: r.maxX + 0.5, y: r.midY - curve * 0.45))
        path.addCurve(to: CGPoint(x: r.maxX - curve, y: r.maxY - 1), control1: CGPoint(x: r.maxX - 2, y: r.maxY - curve * 0.2), control2: CGPoint(x: r.maxX - curve * 0.38, y: r.maxY))
        path.addCurve(to: CGPoint(x: r.minX + curve * 0.82, y: r.maxY - 0.5), control1: CGPoint(x: r.width * 0.66, y: r.maxY + 1.5), control2: CGPoint(x: r.width * 0.31, y: r.maxY - 1.8))
        path.addCurve(to: CGPoint(x: r.minX + 1, y: r.midY), control1: CGPoint(x: r.minX + curve * 0.3, y: r.maxY), control2: CGPoint(x: r.minX - 0.5, y: r.maxY - curve * 0.32))
        path.addCurve(to: CGPoint(x: r.minX + curve, y: r.minY + 1.5), control1: CGPoint(x: r.minX + 1.8, y: r.minY + curve * 0.23), control2: CGPoint(x: r.minX + curve * 0.42, y: r.minY + 0.8))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> HandDrawnCapsule {
        var copy = self
        copy.inset += amount
        return copy
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
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
