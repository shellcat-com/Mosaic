import SwiftUI

struct TilePlacementView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let contribution: TileContribution
    @AppStorage(ContextualEducationProgress.passTheTileShownKey) private var hasShownPassTheTile = false
    @State private var placed = false
    @State private var showPassTheTile = false

    var body: some View {
        VStack(spacing: 28) {
            MosaicProgressRail(current: 5, total: 5, tint: MosaicTheme.sage)
                .padding(.horizontal, 22)
                .padding(.top, 12)

            Spacer()
            ZStack {
                Circle()
                    .fill(MosaicTheme.sage.opacity(0.14))
                    .frame(width: 270, height: 270)
                CeramicTile(
                    category: contribution.mission.category,
                    emotion: contribution.emotion,
                    evidence: contribution.evidence,
                    isRevived: contribution.isRevived,
                    size: 176
                )
                .scaleEffect(placed ? 0.88 : 1)
                .rotationEffect(.degrees(placed ? 0 : -3))
            }

            VStack(spacing: 10) {
                Text(placed ? "Your tile has a place" : "Place your tile")
                    .font(MosaicTheme.display(36, weight: .semibold))
                Text(placed ? "Your kindness is now part of the shared Mosaic." : "Every act gets equal space in the community artwork.")
                    .font(MosaicTheme.body())
                    .foregroundStyle(MosaicTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Spacer()
            Button(completionButtonTitle) {
                if placed {
                    if hasShownPassTheTile {
                        dismiss()
                    } else {
                        hasShownPassTheTile = true
                        showPassTheTile = true
                    }
                } else {
                    store.addContribution(contribution)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { placed = true }
                }
            }
            .buttonStyle(PrimaryButtonStyle(color: placed ? MosaicTheme.sage : MosaicTheme.indigo))
            .padding(20)
        }
        .porcelainBackground()
        .navigationBarBackButtonHidden(placed)
        .fullScreenCover(isPresented: $showPassTheTile, onDismiss: dismiss.callAsFunction) {
            PassTheTileView(contribution: contribution)
                .environment(store)
        }
    }

    private var completionButtonTitle: String {
        if !placed { return "Place my tile" }
        return hasShownPassTheTile ? "Done" : "Continue"
    }
}
