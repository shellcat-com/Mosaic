import SwiftUI

struct MissionLibraryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    MosaicSectionHeader(title: "Choose a mission", eyebrow: "Small acts matter", icon: .heart)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(MosaicTheme.body(.semibold))
                }

                Text("Pick something kind that fits your day. Your evidence stays private unless you choose to share a memory.")
                    .font(MosaicTheme.body())
                    .foregroundStyle(MosaicTheme.muted)

                LazyVStack(spacing: 15) {
                    ForEach(store.missions) { mission in
                        NavigationLink {
                            MissionDetailView(mission: mission)
                        } label: {
                            OrganicPanel(variant: .leaningRight, tint: mission.category == .community ? MosaicTheme.sage.opacity(0.12) : MosaicTheme.paper) {
                                HStack(spacing: 16) {
                                    CeramicTile(category: mission.category, emotion: .caring, evidence: mission.evidence.first ?? .reflection, size: 72)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(mission.title)
                                            .font(MosaicTheme.display(21, weight: .semibold))
                                            .foregroundStyle(MosaicTheme.ink)
                                        Text("\(mission.minutes) min · \(mission.effort)")
                                            .font(MosaicTheme.caption(.semibold))
                                            .foregroundStyle(MosaicTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(MosaicTheme.indigo)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Missions")
        .navigationBarTitleDisplayMode(.inline)
    }
}
