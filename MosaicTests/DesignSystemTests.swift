import SwiftUI
import Testing
import UIKit
@testable import Mosaic

@MainActor
struct DesignSystemTests {
    @Test func frauncesFontsAreBundledAndRegisterable() {
        MosaicFontRegistrar.register()

        for resourceName in MosaicFontRegistrar.resourceNames {
            #expect(Bundle.main.url(forResource: resourceName, withExtension: "ttf") != nil)
        }
        #expect(UIFont(name: MosaicFontRegistrar.regularPostScriptName, size: 24) != nil)
        #expect(UIFont(name: MosaicFontRegistrar.semiboldPostScriptName, size: 24) != nil)
        #expect(UIFont(name: MosaicFontRegistrar.boldPostScriptName, size: 24) != nil)
    }

    @Test func originalArtworkInventoryIsComplete() {
        #expect(MosaicIcon.allCases.count == 15)
        #expect(MosaicIcon.allCases.allSatisfy { !$0.accessibilityLabel.isEmpty })
        #expect(MosaicStickerKind.allCases.count == 6)
    }

    @Test func everyMissionCategoryHasADistinctDoodleIcon() {
        let icons = MissionCategory.allCases.map(\.mosaicIcon)
        #expect(icons.count == MissionCategory.allCases.count)
        #expect(Set(icons).count == MissionCategory.allCases.count)
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func primaryTextMeetsContrastTarget(style: UIUserInterfaceStyle) {
        let ink = resolved(MosaicTheme.ink, style: style)
        let canvas = resolved(MosaicTheme.canvas, style: style)
        let paper = resolved(MosaicTheme.paper, style: style)

        #expect(contrast(ink, canvas) >= 4.5)
        #expect(contrast(ink, paper) >= 4.5)
    }

    private func resolved(_ color: Color, style: UIUserInterfaceStyle) -> UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    private func contrast(_ first: UIColor, _ second: UIColor) -> Double {
        let lighter = max(luminance(first), luminance(second))
        let darker = min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)

        func channel(_ value: CGFloat) -> Double {
            let component = Double(value)
            return component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }
}
