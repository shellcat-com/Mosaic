import SwiftUI

struct MissionDetailView: View {
    let mission: Mission
    @State private var begin = false

    var body: some View {
        MosaicScreen {
            VStack(spacing: 26) {
                MosaicProgressRail(current: 1, total: 5, tint: MosaicTheme.persimmon)
                    .frame(maxWidth: .infinity, alignment: .leading)
                CeramicTile(category: mission.category, emotion: .caring, evidence: mission.evidence.first ?? .reflection, size: 150)
                    .rotationEffect(.degrees(-1.5))
                    .overlay(alignment: .topTrailing) {
                        MosaicSticker(kind: .sparkles, size: 52)
                            .offset(x: 26, y: -22)
                    }
                    .padding(.vertical, 12)

                VStack(spacing: 10) {
                    Label("CHOOSE A MISSION", systemImage: "sun.max.fill")
                        .font(MosaicTheme.caption(.bold))
                        .foregroundStyle(MosaicTheme.persimmon)
                    Text(mission.title)
                        .font(MosaicTheme.display(36, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text(mission.detail)
                        .font(MosaicTheme.body())
                        .foregroundStyle(MosaicTheme.muted)
                        .multilineTextAlignment(.center)
                }

                OrganicPanel(variant: .leaningRight) {
                    VStack(alignment: .leading, spacing: 17) {
                        detailRow(icon: "clock", title: "Fits your day", detail: "About \(mission.minutes) minutes · \(mission.effort)")
                        detailRow(icon: "checkmark.shield", title: "Verify your way", detail: mission.evidence.map(\.title).joined(separator: ", "))
                        detailRow(icon: "eye.slash", title: "Private by default", detail: "Evidence is only seen by the organizer.")
#if DEBUG
                        if MarketingPreviewScene.current != .mission {
                            detailRow(icon: "person.badge.clock", title: "Partner confirmation", detail: "Planned after the hackathon; not required for this mission.")
                        }
#else
                        detailRow(icon: "person.badge.clock", title: "Partner confirmation", detail: "Planned after the hackathon; not required for this mission.")
#endif
                    }
                }
            }
        }
        .navigationTitle("Mission")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Complete this act") { begin = true }
                .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.persimmon))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
        }
        .navigationDestination(isPresented: $begin) {
            EvidenceView(mission: mission)
        }
    }

    private func detailRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(MosaicTheme.indigo)
                .frame(width: 36, height: 36)
                .background(MosaicTheme.indigo.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(MosaicTheme.muted)
            }
        }
    }
}
