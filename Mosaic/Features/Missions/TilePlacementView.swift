import SwiftUI

struct TilePlacementView: View {
    let contribution: TileContribution
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGSize = .zero
    @State private var placed = false
    @State private var showFinish = false

    var body: some View {
        MosaicScreen {
            VStack(spacing: 22) {
                MosaicProgressRail(current: 5, total: 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 5) {
                    Text(placed ? "You’re part of the picture" : "Place your tile")
                        .font(MosaicTheme.display(36, weight: .semibold))
                    Text(placed ? "Every tile carries equal weight." : "Drag toward the open space, or use the Place button.")
                        .font(.subheadline).foregroundStyle(MosaicTheme.muted)
                        .multilineTextAlignment(.center)
                }

                CeramicTile(
                    category: contribution.mission.category,
                    emotion: contribution.emotion,
                    evidence: contribution.evidence,
                    size: placed ? 0 : 96
                )
                .opacity(placed ? 0 : 1)
                .offset(dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { dragOffset = $0.translation }
                        .onEnded { value in
                            if value.translation.height > 45 { placeTile() }
                            else { withAnimation(.spring) { dragOffset = .zero } }
                        }
                )
                .accessibilityHint("Drag down to place in the mosaic")

                MosaicBoard(
                    contributions: Array((placed ? store.challenge.contributions : store.challenge.contributions).suffix(19)),
                    columns: 5, tileSize: 55, showOpenPosition: !placed
                )
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.8), value: placed)

                if !placed {
                    Button("Place in open space") { placeTile() }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Continue") { showFinish = true }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .navigationBarBackButtonHidden(placed)
        .navigationDestination(isPresented: $showFinish) {
            PassTheTileView(contribution: contribution)
        }
    }

    private func placeTile() {
        guard !placed else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.72)) {
            dragOffset = .zero
            store.addContribution(contribution)
            placed = true
        }
    }
}
