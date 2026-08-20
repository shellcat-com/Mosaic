import SwiftUI

struct EventDetailView: View {
    @Environment(AppStore.self) private var store
    let summary: ChallengeSummary
    @State private var showingCalendar = false
    @State private var showingReminders = false
    @State private var showingRecap = false
    @State private var liveMessage: String?

    private var event: ChallengeSummary { store.summary(for: summary.id) ?? summary }
    private var phase: ChallengePhase { event.phase() }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                hero
                timing
                if store.calendarUpdateRequired.contains(event.id) {
                    scheduleChanged
                }
                progress
                actions
            }
        }
        .navigationTitle("Event")
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
        .fullScreenCover(isPresented: $showingRecap) {
            RecapEditorView(challenge: store.challenge)
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
                Text("Mosaic rescheduled your reminders. If you previously added this event to Calendar, open the editor to update your copy.")
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
                    .accessibilityLabel("Challenge progress")
                    .accessibilityValue("\(event.contributionCount) of \(event.goal) acts")
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if phase == .completed {
            VStack(spacing: 12) {
                Button {
                    Task {
                        await store.openChallenge(event.id)
                        showingRecap = true
                    }
                } label: {
                    Label("Watch recap", systemImage: "play.rectangle.fill")
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
        } else {
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
        case .upcoming: "The challenge begins soon"
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
                    Toggle("Challenge begins", isOn: $preferences.challengeStart)
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
