import SwiftUI

struct EventDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(MosaicRouter.self) private var router
    let summary: ChallengeSummary
    @State private var showingCalendar = false
    @State private var showingReminders = false
    @State private var liveMessage: String?

    private var event: ChallengeSummary { store.summary(for: summary.id) ?? summary }
    private var phase: ChallengePhase { event.phase() }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                hero
                contributionActions
                progress
                timing
                if store.calendarUpdateRequired.contains(event.id) {
                    scheduleChanged
                }
                scheduleActions
            }
        }
        .navigationTitle("Mosaic")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCalendar) {
            CalendarEventSheet(summary: event) {
                store.calendarUpdateRequired.remove(event.id)
            }
        }
        .sheet(isPresented: $showingReminders) {
            ReminderPreferencesView(summary: event) {
                showingReminders = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    showingCalendar = true
                }
            }
                .presentationDetents([.medium, .large])
        }
        .task { await store.openChallenge(event.id) }
    }

    private var hero: some View {
        OrganicPanel(variant: .leaningLeft, tint: phaseTint.opacity(0.13)) {
            VStack(alignment: .leading, spacing: 12) {
                KinderArtworkView(
                    selection: event.theme,
                    phase: phase == .completed ? .recap : .sealed,
                    cornerRadius: 22,
                    showsTitle: false
                )
                .frame(height: 220)
                HStack {
                    Label(phase.title.uppercased(), systemImage: phaseSymbol)
                        .font(MosaicTheme.caption(.bold))
                        .tracking(0.8)
                        .foregroundStyle(phaseTint)
                    Spacer()
                    MosaicSticker(kind: phase == .completed ? .sparkles : .ceramicSun, size: 54)
                }
                Text(event.name)
                    .font(MosaicTheme.display(36, weight: .semibold))
                Text(event.purpose)
                    .font(.subheadline)
                    .foregroundStyle(MosaicTheme.muted)
                Text(event.groupName.uppercased())
                    .font(MosaicTheme.caption(.bold))
                    .tracking(0.7)
                    .foregroundStyle(MosaicTheme.muted)
            }
        }
    }

    private var timing: some View {
        OrganicPanel {
            VStack(alignment: .leading, spacing: 16) {
                MosaicSectionHeader(title: timingTitle, eyebrow: "Schedule", icon: .kiln)
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.revealAt.formatted(date: .complete, time: .shortened))
                            .font(MosaicTheme.body(.semibold))
                        Text("\(TimeZone.current.identifier) · \(TimeZone.current.abbreviation(for: event.revealAt) ?? "Local time")")
                            .font(.caption)
                            .foregroundStyle(MosaicTheme.muted)
                    }
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(MosaicTheme.indigo)
                }
                if phase != .completed {
                    HStack {
                        Text("Countdown")
                        Spacer()
                        Text(event.revealAt, style: .relative)
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private var scheduleChanged: some View {
        OrganicPanel(tint: MosaicTheme.gold.opacity(0.12)) {
            VStack(alignment: .leading, spacing: 10) {
                Label("The reveal time changed", systemImage: "calendar.badge.exclamationmark")
                    .font(.headline)
                Text("Mosaic rescheduled your reminders. If you previously added this Mosaic to Calendar, open the editor to update your copy.")
                    .font(.footnote)
                    .foregroundStyle(MosaicTheme.muted)
                Button("Update Calendar") { showingCalendar = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var progress: some View {
        OrganicPanel(variant: .leaningRight) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Collective progress")
                        .font(MosaicTheme.display(24, weight: .semibold))
                    Spacer()
                    Text("\(event.contributionCount)/\(event.goal)")
                        .font(.headline.monospacedDigit())
                }
                ProgressView(value: event.progress)
                    .tint(MosaicTheme.persimmon)
                    .accessibilityLabel("Mosaic progress")
                    .accessibilityValue("\(event.contributionCount) of \(event.goal) acts")
            }
        }
    }

    @ViewBuilder
    private var contributionActions: some View {
        if event.isShowcase {
            OrganicPanel(variant: .leaningRight, tint: MosaicTheme.indigo.opacity(0.08)) {
                VStack(alignment: .leading, spacing: 14) {
                    MosaicSectionHeader(title: "Read-only showcase", eyebrow: "Example Mosaic", icon: .kintsugi)
                    Text("This shared example cannot accept evidence or memories.")
                        .font(.subheadline)
                        .foregroundStyle(MosaicTheme.muted)
                    if let challengeID = store.writableContributionChallengeID {
                        Button("Create in my private Mosaic") {
                            router.showMissions(for: challengeID)
                        }
                        .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.persimmon))
                    }
                }
            }
        } else {
            contributionActions(for: phase)
        }
    }

    @ViewBuilder
    private func contributionActions(for phase: ChallengePhase) -> some View {
        switch phase {
        case .completed:
            VStack(spacing: 12) {
                Button { router.showRecap(for: event.id) } label: {
                    Label("Open recap", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    store.keepOnWidget(event)
                    liveMessage = "This recap will stay on your automatic widget."
                } label: {
                    Label("Keep on Widget", systemImage: "rectangle.3.group.fill")
                }
                .buttonStyle(SecondaryButtonStyle())

                ShareLink(item: event.recapDeepLink ?? event.deepLink!) {
                    Label("Share recap", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        case .reveal:
            OrganicPanel(variant: .leaningRight, tint: MosaicTheme.gold.opacity(0.12)) {
                VStack(alignment: .leading, spacing: 14) {
                    MosaicSectionHeader(title: "Your Mosaic is ready", eyebrow: "Reveal", icon: .kintsugi)
                    Text("Contributions are closed. Open the artwork and approved memories together.")
                        .font(.subheadline)
                        .foregroundStyle(MosaicTheme.muted)
                    Button("Open reveal") { router.showReveal(for: event.id) }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        case .upcoming:
            OrganicPanel(variant: .leaningRight, tint: MosaicTheme.sky.opacity(0.12)) {
                VStack(alignment: .leading, spacing: 12) {
                    MosaicSectionHeader(title: "Contributions open soon", eyebrow: "Get ready", icon: .spark)
                    Text("Beginning \(event.startAt.formatted(date: .abbreviated, time: .shortened)), you can complete an act or add a memory here.")
                        .font(.subheadline)
                        .foregroundStyle(MosaicTheme.muted)
                }
            }
        case .active:
            OrganicPanel(variant: .leaningRight, tint: MosaicTheme.indigo.opacity(0.08)) {
                VStack(alignment: .leading, spacing: 16) {
                    MosaicSectionHeader(title: "Add to this Mosaic", eyebrow: "Two ways to contribute", icon: .spark)
                    Text("Complete an act to create a tile, or add a memory for the reveal and recap.")
                        .font(.subheadline)
                        .foregroundStyle(MosaicTheme.muted)
                    Button("Complete an act") {
                        router.showMissions(for: event.id)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.persimmon))
                    Button("Add a memory") {
                        router.showMemoryComposer(for: event.id)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleActions: some View {
        if phase != .completed {
            VStack(spacing: 12) {
                Button { showingReminders = true } label: {
                    Label("Remind me", systemImage: "bell.badge")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button { showingCalendar = true } label: {
                    Label("Add to Calendar", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    Task {
                        do {
                            let result = try await store.followLive(event)
                            liveMessage = switch result {
                            case .started: "The reveal is now on your Lock Screen."
                            case .scheduled: "We’ll remind you 30 minutes before the reveal."
                            case .unavailable: "Live Activities are disabled in Settings."
                            }
                        } catch {
                            liveMessage = "Live updates could not be enabled right now."
                        }
                    }
                } label: {
                    Label("Follow live", systemImage: "wave.3.right.circle")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }

        if let liveMessage {
            Text(liveMessage)
                .font(.footnote)
                .foregroundStyle(MosaicTheme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var phaseTint: Color {
        switch phase {
        case .upcoming: MosaicTheme.sky
        case .active: MosaicTheme.sage
        case .reveal: MosaicTheme.persimmon
        case .completed: MosaicTheme.indigo
        }
    }

    private var phaseSymbol: String {
        switch phase {
        case .upcoming: "calendar"
        case .active: "sparkles"
        case .reveal: "light.max"
        case .completed: "play.rectangle"
        }
    }

    private var timingTitle: String {
        switch phase {
        case .upcoming: "This Mosaic begins soon"
        case .active: "The mosaic is still growing"
        case .reveal: "The reveal is open"
        case .completed: "Revealed together"
        }
    }
}

struct ReminderPreferencesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let summary: ChallengeSummary
    let onCalendarFallback: () -> Void
    @State private var preferences = NotificationPreferences.helpful
    @State private var permissionState: NotificationPermissionState = .notDetermined
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Helpful reminders") {
                    Toggle("Mosaic begins", isOn: $preferences.challengeStart)
                    Toggle("24 hours before reveal", isOn: $preferences.revealDayBefore)
                    Toggle("1 hour before reveal", isOn: $preferences.revealHourBefore)
                    Toggle("Reveal begins", isOn: $preferences.revealNow)
                    Toggle("Recap is ready", isOn: $preferences.recapReady)
                }
                Section("Live updates") {
                    Toggle("Lock Screen Live Activity", isOn: $preferences.liveActivity)
                }
                if permissionState == .denied {
                    Section {
                        Button("Open Notification Settings") {
                            openURL(URL(string: UIApplication.openSettingsURLString)!)
                        }
                        Button("Add to Calendar Instead") { onCalendarFallback() }
                    } footer: {
                        Text("Notifications are currently disabled. You can still add the reveal to Calendar.")
                    }
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task {
                            permissionState = await store.saveNotificationPreferences(
                                preferences,
                                for: summary
                            )
                            isSaving = false
                            if permissionState == .allowed || !preferences.remindersEnabled {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear { preferences = store.preferences(for: summary.id) }
        }
    }
}
