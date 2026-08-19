import SwiftUI

struct MosaicsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mosaics")
                            .font(MosaicTheme.display(42, weight: .semibold))
                        Text("Every act holds an equal place.")
                            .font(.subheadline)
                            .foregroundStyle(MosaicTheme.muted)
                    }
                    Spacer()
                    MosaicSticker(kind: .sparkles, size: 58)
                }

                challengeCard
                yourTile
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: Binding(get: { store.showReveal }, set: { store.showReveal = $0 })) {
            RevealView()
        }
    }

    private var challengeCard: some View {
        OrganicPanel(variant: .leaningLeft) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 7) {
                        DoodleIcon(icon: .kiln, color: MosaicTheme.persimmon)
                            .frame(width: 18, height: 18)
                        Text("ACTIVE")
                    }
                    .font(MosaicTheme.caption(.bold))
                    .tracking(0.8)
                    .foregroundStyle(MosaicTheme.persimmon)
                    Spacer()
                    Text(store.challenge.revealDate, style: .relative)
                        .font(MosaicTheme.caption(.semibold))
                        .foregroundStyle(MosaicTheme.muted)
                }

                Text(store.challenge.name)
                    .font(MosaicTheme.display(32, weight: .semibold))

                MosaicBoard(contributions: Array(store.challenge.contributions.prefix(15)), columns: 5, tileSize: 47)
                    .frame(maxWidth: .infinity)

                HStack {
                    Text("\(store.challenge.contributions.count) of \(store.challenge.goal) acts")
                    Spacer()
                    Label("Invitation only", systemImage: "lock.fill")
                }
                .font(MosaicTheme.caption(.medium))
                .foregroundStyle(MosaicTheme.muted)

                ProgressView(value: Double(store.challenge.contributions.count), total: Double(store.challenge.goal))
                    .tint(MosaicTheme.persimmon)

                Button("Preview reveal ceremony") { store.showReveal = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var yourTile: some View {
        OrganicPanel(variant: .leaningRight, tint: MosaicTheme.sage.opacity(0.1)) {
            VStack(alignment: .leading, spacing: 16) {
                MosaicSectionHeader(title: "Your tile", eyebrow: "Your mark", icon: .tile)
                if let contribution = store.pendingContribution {
                    HStack(spacing: 16) {
                        CeramicTile(category: contribution.mission.category, emotion: contribution.emotion, evidence: contribution.evidence, size: 76)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(contribution.mission.title)
                                .font(.headline)
                            Text("Placed · Ready for reveal")
                                .font(.subheadline)
                                .foregroundStyle(MosaicTheme.sage)
                        }
                    }
                } else {
                    HStack(spacing: 17) {
                        MosaicSticker(kind: .ceramicSun, size: 82)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Your space is waiting")
                                .font(MosaicTheme.display(23, weight: .semibold))
                            Text("Complete an act to create and place your first tile.")
                                .font(.subheadline)
                                .foregroundStyle(MosaicTheme.muted)
                        }
                    }
                }
            }
        }
    }
}
