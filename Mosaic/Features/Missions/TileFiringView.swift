import SwiftUI

struct TileFiringView: View {
    let contribution: TileContribution
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fired = false
    @State private var glow = false
    @State private var continueToPlacement = false

    var body: some View {
        VStack(spacing: 30) {
            MosaicProgressRail(current: 4, total: 5, tint: MosaicTheme.persimmon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 12)
            Spacer(minLength: 12)
            ZStack {
                Circle()
                    .fill((fired ? contribution.emotion.color : MosaicTheme.clay).opacity(glow ? 0.38 : 0.18))
                    .frame(width: 260, height: 260)
                    .blur(radius: glow ? 16 : 4)
                CeramicTile(
                    category: contribution.mission.category,
                    emotion: fired ? contribution.emotion : .calm,
                    evidence: contribution.evidence,
                    size: 170
                )
                .saturation(fired ? 1 : 0.12)
                .scaleEffect(glow ? 1.03 : 0.96)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : (fired ? 0 : 8)), axis: (x: 1, y: 0, z: 0))
                if fired {
                    MosaicSticker(kind: .sparkles, size: 62)
                        .offset(x: 108, y: -92)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(spacing: 10) {
                Text(fired ? "Your tile is fired" : "Firing your tile…")
                    .font(MosaicTheme.display(36, weight: .semibold))
                Text(fired ? "Your act now has an equal place in the community artwork." : "Color, pattern, and texture are becoming part of your story.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MosaicTheme.muted)
                    .padding(.horizontal, 38)
            }
            Spacer()
            if fired {
                Button("Place my tile") { continueToPlacement = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .porcelainBackground()
        .navigationBarBackButtonHidden(fired)
        .task {
            if reduceMotion {
                fired = true
            } else {
                withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) { glow = true }
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeOut(duration: 0.4)) { fired = true; glow = false }
            }
        }
        .navigationDestination(isPresented: $continueToPlacement) {
            TilePlacementView(contribution: contribution)
        }
    }
}
