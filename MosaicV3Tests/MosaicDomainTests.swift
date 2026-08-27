import Foundation
import Testing
import UIKit
@testable import Mosaic

struct MosaicDomainTests {
    @Test(arguments: MosaicDraft.supportedGoals)
    func supportedBoardGoalsArePerfectSquares(_ goal: Int) {
        let side = Int(Double(goal).squareRoot())
        #expect(side * side == goal)
    }

    @Test
    func phasesRespectStartCapacityAndFixedReveal() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(MosaicPhase.resolve(startAt: now.addingTimeInterval(10), revealAt: now.addingTimeInterval(100), contributionCount: 0, goal: 9, now: now) == .scheduled)
        #expect(MosaicPhase.resolve(startAt: now.addingTimeInterval(-10), revealAt: now.addingTimeInterval(100), contributionCount: 8, goal: 9, now: now) == .active)
        #expect(MosaicPhase.resolve(startAt: now.addingTimeInterval(-10), revealAt: now.addingTimeInterval(100), contributionCount: 9, goal: 9, now: now) == .full)
        #expect(MosaicPhase.resolve(startAt: now.addingTimeInterval(-10), revealAt: now, contributionCount: 1, goal: 9, now: now) == .revealed)
        #expect(MosaicPhase.full.acceptsPhotos)
        #expect(!MosaicPhase.full.acceptsContributions)
    }

    @Test
    func incompleteBoardStillRevealsAtTime() {
        let reveal = Date(timeIntervalSince1970: 2_000)
        #expect(MosaicPhase.resolve(startAt: reveal.addingTimeInterval(-1_000), revealAt: reveal, contributionCount: 2, goal: 100, now: reveal) == .revealed)
    }

    @Test
    func draftRejectsUnsupportedLimitsAndInvalidTiming() {
        var draft = MosaicDraft()
        draft.name = "A Mosaic"
        draft.communityName = "Neighbors"
        draft.activities = [.init(title: "Help", purpose: "")]
        #expect(draft.isValid)
        draft.goal = 10
        #expect(!draft.isValid)
        draft.goal = 9
        draft.shotLimit = 13
        #expect(!draft.isValid)
        draft.shotLimit = 12
        draft.revealAt = draft.startAt
        #expect(!draft.isValid)
    }

    @Test @MainActor
    func accentForegroundKeepsReadableContrastInBothAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let accent = UIColor(MosaicTheme.accentForeground).resolvedColor(with: traits)
            let canvas = UIColor(MosaicTheme.canvas).resolvedColor(with: traits)
            let paper = UIColor(MosaicTheme.paper).resolvedColor(with: traits)

            #expect(Self.contrastRatio(accent, canvas) >= 4.5)
            #expect(Self.contrastRatio(accent, paper) >= 4.5)
        }
    }

    @Test @MainActor
    func secondaryForegroundKeepsReadableContrastAcrossMaterials() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let foreground = UIColor(MosaicTheme.muted).resolvedColor(with: traits)
            for backgroundColor in [MosaicTheme.canvas, MosaicTheme.paper, MosaicTheme.claySurface] {
                let background = UIColor(backgroundColor).resolvedColor(with: traits)
                #expect(Self.contrastRatio(foreground, background) >= 4.5)
            }
        }
    }

    @Test @MainActor
    func primaryButtonForegroundKeepsReadableContrast() {
        let foreground = UIColor.white
        let background = UIColor(MosaicTheme.deepGlaze)
        #expect(Self.contrastRatio(foreground, background) >= 4.5)
    }

    private static func contrastRatio(_ first: UIColor, _ second: UIColor) -> Double {
        let lighter = max(relativeLuminance(first), relativeLuminance(second))
        let darker = min(relativeLuminance(first), relativeLuminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }

        func linearize(_ component: CGFloat) -> Double {
            let value = Double(component)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }
}
