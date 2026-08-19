import SwiftUI

struct MissionLibraryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var category: MissionCategory?

    private var filteredMissions: [Mission] {
        guard let category else { return store.missions }
        return store.missions.filter { $0.category == category }
    }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 21) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Choose one small act")
                            .font(MosaicTheme.display(38, weight: .semibold))
                        Text("Pick what fits your time and energy today.")
                            .font(.subheadline)
                            .foregroundStyle(MosaicTheme.muted)
                    }
                    Spacer(minLength: 0)
                    MosaicSticker(kind: .neighborhoodSprout, size: 58)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        FilterChip(title: "All", selected: category == nil) { category = nil }
                        ForEach(MissionCategory.allCases) { item in
                            FilterChip(title: item.title, selected: category == item) { category = item }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .contentMargins(.horizontal, 1, for: .scrollContent)

                LazyVStack(spacing: 14) {
                    ForEach(filteredMissions) { mission in
                        NavigationLink(value: mission) {
                            MissionRow(mission: mission)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(MosaicTheme.paper, in: Circle())
                        .overlay(Circle().stroke(MosaicTheme.border, lineWidth: 1))
                }
                .accessibilityLabel("Close")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Mission.self) { mission in
            MissionDetailView(mission: mission)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(selected ? Color.white : MosaicTheme.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 42)
            .background(selected ? MosaicTheme.indigo : MosaicTheme.paper, in: HandDrawnCapsule(inset: 0))
            .overlay { HandDrawnCapsule(inset: 1).stroke(selected ? MosaicTheme.indigo : MosaicTheme.border, lineWidth: 1) }
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct MissionRow: View {
    let mission: Mission

    var body: some View {
        HStack(spacing: 15) {
            CeramicTile(category: mission.category, emotion: emotion, size: 68)
            VStack(alignment: .leading, spacing: 6) {
                Text(mission.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(MosaicTheme.ink)
                Text(mission.detail)
                    .font(.subheadline)
                    .foregroundStyle(MosaicTheme.muted)
                    .lineLimit(2)
                HStack(spacing: 12) {
                    Label("\(mission.minutes) min", systemImage: "clock")
                    Label(mission.effort, systemImage: "figure.walk")
                }
                .font(MosaicTheme.caption())
                .foregroundStyle(MosaicTheme.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MosaicTheme.muted.opacity(0.7))
        }
        .porcelainCard()
    }

    private var emotion: Emotion {
        Emotion.allCases[MissionCategory.allCases.firstIndex(of: mission.category, offsetBy: 0) % Emotion.allCases.count]
    }
}

private extension Array where Element: Equatable {
    func firstIndex(of element: Element, offsetBy offset: Int) -> Int {
        firstIndex(of: element).map { distance(from: startIndex, to: $0) + offset } ?? offset
    }
}
