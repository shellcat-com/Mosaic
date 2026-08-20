import SwiftUI

struct PassTheTileView: View {
    let contribution: TileContribution
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false

    private var invitationText: String {
        "I added an act of kindness to \(store.challenge.name). Pass the Tile and add yours: https://mosaic.app/join/\(store.challenge.invitationCode)"
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                CeramicTile(category: contribution.mission.category, emotion: contribution.emotion, evidence: contribution.evidence, size: 160)
                DoodleIcon(icon: .chain, color: .white, lineWidth: 2.8)
                    .frame(width: 30, height: 30)
                    .frame(width: 58, height: 58)
                    .background(MosaicTheme.indigo, in: OrganicPanelShape(variant: .leaningRight))
                    .offset(x: 78, y: -72)
            }

            VStack(spacing: 10) {
                Text("Pass the Tile")
                    .font(MosaicTheme.display(38, weight: .semibold))
                Text("Invite someone to continue the chain. If the invitation rests and is revived later, a gold kintsugi connection will mark the return.")
                    .foregroundStyle(MosaicTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            VStack(spacing: 12) {
                ShareLink(item: invitationText) {
                    Label("Invite someone", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Not now") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle(color: MosaicTheme.ink))
            }
            .padding(20)
            Spacer(minLength: 10)
        }
        .porcelainBackground()
        .navigationBarBackButtonHidden()
    }
}
