import SwiftUI

struct MosaicsView: View {
    @Environment(AppStore.self) private var store
    @State private var filter: EventLibraryFilter = .active
    @State private var displayedMonth = Date.now

    private var filteredEvents: [ChallengeSummary] {
        store.challengeLibrary
            .filter { summary in
                let phase = summary.phase()
                let phaseMatches = switch filter {
                case .upcoming: phase == .upcoming
                case .active: phase == .active || phase == .reveal
                case .recaps: phase == .completed
                }
                return phaseMatches && Calendar.current.isDate(summary.revealAt, equalTo: displayedMonth, toGranularity: .month)
            }
            .sorted { $0.revealAt < $1.revealAt }
    }

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

                monthPicker

                Picker("Challenge status", selection: $filter) {
                    ForEach(EventLibraryFilter.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                agenda

                if filter == .active { yourTile }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: Binding(get: { store.showReveal }, set: { store.showReveal = $0 })) {
            RevealView()
        }
    }

    private var monthPicker: some View {
        HStack {
            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(displayedMonth.formatted(.dateTime.month(.wide)))
                    .font(MosaicTheme.display(28, weight: .semibold))
                Text(displayedMonth.formatted(.dateTime.year()))
                    .font(MosaicTheme.caption(.bold))
                    .foregroundStyle(MosaicTheme.muted)
            }
            Spacer()
            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(MosaicTheme.indigo)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var agenda: some View {
        if filteredEvents.isEmpty {
            OrganicPanel(tint: MosaicTheme.claySurface.opacity(0.5)) {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: filter == .recaps ? "play.rectangle" : "calendar",
                    description: Text("Use the month arrows to explore your Mosaic history.")
                )
            }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(groupedEvents, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(MosaicTheme.caption(.bold))
                            .tracking(0.5)
                            .foregroundStyle(MosaicTheme.muted)
                        ForEach(group.events) { summary in
                            NavigationLink { EventDetailView(summary: summary) } label: {
                                EventAgendaRow(summary: summary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var groupedEvents: [(date: Date, events: [ChallengeSummary])] {
        let grouped = Dictionary(grouping: filteredEvents) {
            Calendar.current.startOfDay(for: $0.revealAt)
        }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    private var emptyTitle: String {
        switch filter {
        case .upcoming: "No upcoming reveals this month"
        case .active: "No active challenges this month"
        case .recaps: "No recaps from this month"
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

private enum EventLibraryFilter: String, CaseIterable, Identifiable {
    case upcoming, active, recaps
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private struct EventAgendaRow: View {
    let summary: ChallengeSummary

    var body: some View {
        OrganicPanel(variant: .softRectangle, tint: tint.opacity(0.1)) {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text(summary.revealAt.formatted(.dateTime.day()))
                        .font(MosaicTheme.display(27, weight: .semibold))
                    Text(summary.revealAt.formatted(.dateTime.month(.abbreviated)))
                        .font(MosaicTheme.caption(.bold))
                        .textCase(.uppercase)
                }
                .frame(width: 50)
                .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.name)
                        .font(.headline)
                        .foregroundStyle(MosaicTheme.ink)
                    Text(summary.revealAt.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(MosaicTheme.muted)
                    ProgressView(value: summary.progress)
                        .tint(tint)
                }
                Spacer(minLength: 4)
                Image(systemName: summary.phase() == .completed ? "play.circle.fill" : "chevron.right")
                    .foregroundStyle(tint)
            }
        }
    }

    private var tint: Color {
        switch summary.phase() {
        case .upcoming: MosaicTheme.sky
        case .active: MosaicTheme.sage
        case .reveal: MosaicTheme.persimmon
        case .completed: MosaicTheme.indigo
        }
    }
}
