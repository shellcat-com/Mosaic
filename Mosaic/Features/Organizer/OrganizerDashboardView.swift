import SwiftUI

struct OrganizerDashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var revealDate: Date

    init() {
        _revealDate = State(initialValue: .now)
    }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Organizer")
                            .font(MosaicTheme.display(39, weight: .semibold))
                        Text("Guide the circle with care.")
                            .font(.subheadline)
                            .foregroundStyle(MosaicTheme.muted)
                    }
                    Spacer()
                    MosaicSticker(kind: .neighborhoodSprout, size: 58)
                }

                challengeSummary

                organizerSection("Invitation", icon: .chain) {
                    VStack(spacing: 0) {
                        row("Challenge code", trailing: store.challenge.invitationCode)
                        Divider().overlay(MosaicTheme.border)
                        ShareLink(item: "Join \(store.challenge.name) in Mosaic: mosaic.app/join/\(store.challenge.invitationCode)") {
                            actionRow("Share invitation", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                organizerSection("Moderation", icon: .heart) {
                    VStack(spacing: 0) {
                        NavigationLink { ReviewQueueView() } label: {
                            navigationRow("Evidence awaiting review", count: store.challenge.contributions.filter { $0.status.needsModeration }.count)
                        }
                        Divider().overlay(MosaicTheme.border)
                        NavigationLink { ReviewQueueView() } label: { navigationRow("Stories awaiting approval", count: 2) }
                        Divider().overlay(MosaicTheme.border)
                        row("Reports", trailing: "0")
                    }
                }

                organizerSection("Reveal", icon: .kiln) {
                    VStack(alignment: .leading, spacing: 16) {
                        DatePicker("Scheduled time", selection: $revealDate)
                            .font(MosaicTheme.body(.medium))
                        Divider().overlay(MosaicTheme.border)
                        Button("Start reveal ceremony") {
                            Task {
                                await store.startReveal()
                                dismiss()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }

                organizerSection("Organizer Plus", icon: .spark) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Custom artwork, recap approval, poster export, and high-resolution artwork.")
                            .font(.subheadline)
                            .foregroundStyle(MosaicTheme.muted)
                        Button("Explore Organizer Plus") { }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .font(.headline)
            }
        }
        .onAppear { revealDate = store.challenge.revealDate }
    }

    private var challengeSummary: some View {
        OrganicPanel(variant: .leaningLeft, tint: MosaicTheme.persimmon.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 10) {
                Text(store.challenge.name)
                    .font(MosaicTheme.display(30, weight: .semibold))
                Text(store.challenge.purpose)
                    .font(.subheadline)
                    .foregroundStyle(MosaicTheme.muted)
                ProgressView(value: Double(store.challenge.contributions.count), total: Double(store.challenge.goal))
                    .tint(MosaicTheme.persimmon)
            }
        }
    }

    private func organizerSection<Content: View>(_ title: String, icon: MosaicIcon, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                DoodleIcon(icon: icon, color: MosaicTheme.muted).frame(width: 19, height: 19)
                Text(title.uppercased())
            }
            .font(MosaicTheme.caption(.bold))
            .tracking(0.8)
            .foregroundStyle(MosaicTheme.muted)
            OrganicPanel(variant: .softRectangle) { content() }
        }
    }

    private func row(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title).foregroundStyle(MosaicTheme.ink)
            Spacer()
            Text(trailing).foregroundStyle(MosaicTheme.muted)
        }
        .font(MosaicTheme.body())
        .frame(minHeight: 52)
    }

    private func actionRow(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
        }
        .font(MosaicTheme.body(.semibold))
        .foregroundStyle(MosaicTheme.indigo)
        .frame(minHeight: 52)
    }

    private func navigationRow(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)").foregroundStyle(MosaicTheme.muted)
            Image(systemName: "chevron.right").foregroundStyle(MosaicTheme.muted.opacity(0.7))
        }
        .font(MosaicTheme.body())
        .foregroundStyle(MosaicTheme.ink)
        .frame(minHeight: 52)
    }
}

private struct ReviewQueueView: View {
    @Environment(AppStore.self) private var store

    private var pending: [TileContribution] {
        store.challenge.contributions.filter { $0.status.needsModeration }
    }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 20) {
                MosaicSectionHeader(title: "Review queue", eyebrow: "Private moderation", icon: .heart)
                if pending.isEmpty {
                    ContentUnavailableView("Queue is clear", systemImage: "checkmark.seal", description: Text("New private evidence will appear here."))
                        .porcelainCard()
                }
                ForEach(Array(pending.enumerated()), id: \.element.id) { index, contribution in
                    OrganicPanel(variant: OrganicPanelVariant.allCases[index % OrganicPanelVariant.allCases.count]) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("\(contribution.evidence.title) evidence", systemImage: contribution.evidence.symbol)
                                    .font(.headline)
                                Spacer()
                                Text("PENDING")
                                    .font(MosaicTheme.caption(.bold))
                                    .foregroundStyle(MosaicTheme.persimmon)
                            }
                            Text(contribution.mission.title)
                                .font(.subheadline.weight(.semibold))
                            Text("Evidence is visible only to this challenge’s organizer. Story approval remains separate.")
                                .font(.footnote)
                                .foregroundStyle(MosaicTheme.muted)
                            HStack {
                                Button("Approve") {
                                    Task { await store.moderate(contribution.id, approved: true, approveMemory: contribution.sharedMemory) }
                                }
                                .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.sage))
                                Button("Reject") {
                                    Task { await store.moderate(contribution.id, approved: false) }
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Review queue")
        .navigationBarTitleDisplayMode(.inline)
    }
}
