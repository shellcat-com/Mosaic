import SwiftUI

struct OrganizerDashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var revealDate: Date
    @State private var scheduleMessage: String?
    @State private var showCreation = false
    @State private var showCatalogReview = false

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

                if store.selectedOrganization?.role.canManageChallenges != false {
                    organizerSection("Artwork & invitation", icon: .mosaic) {
                        VStack(alignment: .leading, spacing: 14) {
                            KinderArtworkView(selection: store.challenge.theme, phase: .invitation, cornerRadius: 22, showsTitle: true)
                                .frame(height: 210)
                            Text("Choose from all 120 handmade Kinder Block artworks. The selection locks when the first tile is placed.")
                                .font(.footnote)
                                .foregroundStyle(MosaicTheme.muted)
                            Button(store.challenge.contributions.isEmpty ? "Design this Kinder Block" : "Artwork locked") {
                                showCreation = true
                            }
                            .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.persimmon))
                            .disabled(!store.challenge.contributions.isEmpty)
                            Button("Review all 120 artworks") {
                                showCatalogReview = true
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }

                if let organization = store.selectedOrganization {
                    organizerSection("Workspace", icon: .people) {
                        VStack(spacing: 0) {
                            row(organization.name, trailing: organization.role.rawValue.capitalized)
                            Divider().overlay(MosaicTheme.border)
                            NavigationLink { WorkspaceSettingsView() } label: {
                                navigationRow("Organization settings", count: store.organizations.count)
                            }
                        }
                    }
                }

                if store.selectedOrganization?.role.canManageChallenges != false {
                    organizerSection("Invitation", icon: .chain) {
                    VStack(spacing: 0) {
                        row("Challenge code", trailing: store.challenge.invitationCode)
                        Divider().overlay(MosaicTheme.border)
                        ShareLink(item: MosaicBuildConfiguration.invitationShareText(challengeName: store.challenge.name, code: store.challenge.invitationCode)) {
                            actionRow("Share invitation", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                }

                organizerSection("Moderation", icon: .heart) {
                    VStack(spacing: 0) {
                        NavigationLink { ReviewQueueView() } label: {
                            navigationRow("Evidence awaiting review", count: store.challenge.contributions.filter { $0.status.needsModeration }.count)
                        }
                        Divider().overlay(MosaicTheme.border)
                        NavigationLink { SharedMomentReviewQueueView() } label: {
                            navigationRow("Shared moments awaiting approval", count: store.challenge.sharedMoments.filter { $0.lifecycle == .sealedPendingReview }.count)
                        }
                        Divider().overlay(MosaicTheme.border)
                        row("Reports", trailing: "0")
                    }
                }

                if store.selectedOrganization?.role.canManageChallenges != false {
                    organizerSection("Reveal", icon: .kiln) {
                    VStack(alignment: .leading, spacing: 16) {
                        DatePicker("Scheduled time", selection: $revealDate)
                            .font(MosaicTheme.body(.medium))
                        Divider().overlay(MosaicTheme.border)
                        Button("Save reveal time") {
                            Task {
                                let saved = await store.scheduleReveal(at: revealDate)
                                scheduleMessage = saved
                                    ? "Reveal time saved. Participant reminders will be rescheduled."
                                    : "Choose a future reveal time."
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        if let scheduleMessage {
                            Text(scheduleMessage)
                                .font(.footnote)
                                .foregroundStyle(MosaicTheme.muted)
                        }
                        Button("Start reveal ceremony") {
                            Task {
                                await store.startReveal()
                                dismiss()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                }

                if MosaicBuildConfiguration.billingEnabled {
                    organizerSection("Organizer Plus", icon: .spark) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Custom artwork, recap approval, poster export, and high-resolution artwork.")
                                .font(.subheadline)
                                .foregroundStyle(MosaicTheme.muted)
                            HStack {
                                Text(store.accessSnapshot.planName)
                                    .font(.headline)
                                Spacer()
                                Text("\(store.accessSnapshot.participantLimit) people")
                                    .font(.footnote).foregroundStyle(MosaicTheme.muted)
                            }
                            if store.accessSnapshot.plusActive {
                                Label("RevenueCat entitlement active", systemImage: "checkmark.seal.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(MosaicTheme.sage)
                            }
                            Button(store.accessSnapshot.plusActive ? "Manage billing" : "Explore Organizer Plus") {
                                if store.accessSnapshot.plusActive {
                                    store.accountMessage = "Open Billing from Profile to manage your Apple subscription."
                                } else {
                                    store.requestPremium(.customArtwork)
                                }
                            }
                                .buttonStyle(SecondaryButtonStyle())
                            if let message = store.accountMessage {
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(MosaicTheme.muted)
                            }
                        }
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
        .fullScreenCover(isPresented: $showCreation) {
            KinderBlockCreationView()
        }
        .sheet(isPresented: $showCatalogReview) {
            NavigationStack { KinderThemeContactSheetView() }
        }
        .sheet(isPresented: Binding(
            get: { MosaicBuildConfiguration.billingEnabled && store.isShowingPaywall },
            set: { store.isShowingPaywall = $0 }
        )) {
            MosaicPaywallView()
        }
    }

    private var challengeSummary: some View {
        OrganicPanel(variant: .leaningLeft, tint: MosaicTheme.persimmon.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 10) {
                KinderArtworkView(selection: store.challenge.theme, phase: .sealed, cornerRadius: 22)
                    .frame(height: 170)
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

private struct SharedMomentReviewQueueView: View {
    @Environment(AppStore.self) private var store
    private var pending: [SharedMoment] { store.challenge.sharedMoments.filter { $0.lifecycle == .sealedPendingReview } }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 20) {
                MosaicSectionHeader(title: "Shared roll", eyebrow: "Private moderation", icon: .memory)
                if pending.isEmpty {
                    ContentUnavailableView("Roll review is clear", systemImage: "envelope.open", description: Text("Newly sealed moments will appear here."))
                        .porcelainCard()
                }
                ForEach(pending) { moment in
                    OrganicPanel(variant: .leaningLeft, tint: MosaicTheme.claySurface) {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Label("Sealed moment", systemImage: "envelope.fill").font(.headline)
                                Spacer()
                                Text("PRIVATE").font(MosaicTheme.caption(.bold)).foregroundStyle(MosaicTheme.persimmon)
                            }
                            if let note = moment.note { Text(note).font(.subheadline).lineLimit(3) }
                            Text("Approval adds this social memory to the reveal. It never creates an action or tile.")
                                .font(.footnote).foregroundStyle(MosaicTheme.muted)
                            HStack {
                                Button("Approve") { Task { await store.moderateSharedMoment(moment.id, approved: true) } }
                                    .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.sage))
                                Button("Reject") { Task { await store.moderateSharedMoment(moment.id, approved: false) } }
                                    .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Shared moments")
        .navigationBarTitleDisplayMode(.inline)
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
