import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var showMissions = false
    @State private var showOrganizer = false
    @State private var presentedEvent: ChallengeSummary?
    @State private var calendarEvent: ChallengeSummary?
    @State private var reminderEvent: ChallengeSummary?
    @State private var liveMessage: String?

    private var progress: Double {
        Double(store.challenge.contributions.count) / Double(store.challenge.goal)
    }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 26) {
                header
                nextUpCard
                if store.challenge.cameraRollEnabled { developingRollCard }
                mosaicHero
                actionCard
                momentum
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showMissions) {
            NavigationStack { MissionLibraryView() }
        }
        .sheet(isPresented: $showOrganizer) {
            NavigationStack { OrganizerDashboardView() }
        }
        .sheet(item: $presentedEvent) { summary in
            NavigationStack { EventDetailView(summary: summary) }
        }
        .sheet(item: $calendarEvent) { summary in
            CalendarEventSheet(summary: summary)
        }
        .sheet(item: $reminderEvent) { summary in
            ReminderPreferencesView(summary: summary) {
                reminderEvent = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    calendarEvent = summary
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: showOrganizer) { _, isPresented in
            if !isPresented { Task { await store.returnToShowcase() } }
        }
        .fullScreenCover(isPresented: Binding(get: { store.showReveal }, set: { store.showReveal = $0 })) {
            RevealView()
        }
    }

    private var developingRollCard: some View {
        let sealed = store.challenge.sharedMoments.filter { $0.lifecycle.isSealed }
        let mine = sealed.filter { $0.creatorID == store.localParticipantID || $0.localAssetName != nil }.count
        return OrganicPanel(variant: .leaningRight, tint: MosaicTheme.claySurface) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR SHARED ROLL").font(MosaicTheme.caption(.bold)).tracking(1.1).foregroundStyle(MosaicTheme.indigo)
                        Text("Your roll is developing")
                            .font(MosaicTheme.display(28, weight: .semibold))
                    }
                    Spacer()
                    Image(systemName: "envelope.fill").font(.title2).foregroundStyle(MosaicTheme.indigo)
                }
                Text("No previews before reveal—just the quiet promise of moments waiting together.")
                    .font(.subheadline).foregroundStyle(MosaicTheme.muted)
                HStack(spacing: 10) {
                    MetricPill(icon: "camera.fill", text: "\(mine) yours")
                    MetricPill(icon: "person.2.fill", text: "\(sealed.count) group")
                    Spacer()
                    Text(store.challenge.revealDate, style: .relative)
                        .font(MosaicTheme.caption(.bold)).foregroundStyle(MosaicTheme.persimmon)
                }
                Button("Capture a moment") { store.openSharedCamera() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("View your sealed roll") { store.showSealedRoll = true }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MosaicTheme.indigo)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var nextUpCard: some View {
        if let next = store.nextChallenge {
            OrganicPanel(variant: .leaningRight, tint: MosaicTheme.sky.opacity(0.11)) {
                VStack(alignment: .leading, spacing: 13) {
                    Button { presentedEvent = next } label: {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Label("NEXT UP", systemImage: "calendar.badge.clock")
                                    .font(MosaicTheme.caption(.bold))
                                    .tracking(0.8)
                                    .foregroundStyle(MosaicTheme.indigo)
                                Spacer()
                                Text(next.revealAt, style: .relative)
                                    .font(MosaicTheme.caption(.bold))
                                    .foregroundStyle(MosaicTheme.persimmon)
                            }
                            Text(next.name)
                                .font(MosaicTheme.display(27, weight: .semibold))
                                .foregroundStyle(MosaicTheme.ink)
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(next.revealAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(TimeZone.current.identifier) · \(TimeZone.current.abbreviation(for: next.revealAt) ?? "Local time")")
                                        .font(.caption)
                                        .foregroundStyle(MosaicTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.headline)
                                    .foregroundStyle(MosaicTheme.indigo)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Open event details")

                    HStack(spacing: 8) {
                        nextUpAction("Remind me", icon: "bell.badge") {
                            reminderEvent = next
                        }
                        nextUpAction("Calendar", icon: "calendar.badge.plus") {
                            calendarEvent = next
                        }
                        nextUpAction("Follow live", icon: "wave.3.right.circle") {
                            Task { await followLive(next) }
                        }
                    }
                    if let liveMessage {
                        Text(liveMessage)
                            .font(.caption)
                            .foregroundStyle(MosaicTheme.muted)
                    }
                }
            }
        }
    }

    private func nextUpAction(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(MosaicTheme.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @MainActor
    private func followLive(_ summary: ChallengeSummary) async {
        do {
            let result = try await store.followLive(summary)
            liveMessage = switch result {
            case .started: "The reveal is now on your Lock Screen."
            case .scheduled: "Live updates will begin 30 minutes before reveal."
            case .unavailable: "Live Activities are disabled in Settings."
            }
        } catch {
            liveMessage = "Live updates could not be enabled right now."
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Mosaic")
                    .font(MosaicTheme.display(44, weight: .semibold))
                Text(store.challenge.name.uppercased())
                    .font(MosaicTheme.caption(.bold))
                    .tracking(1.2)
                    .foregroundStyle(MosaicTheme.muted)
            }
            Spacer()
            Button {
                Task {
                    await store.openOrganizerSandbox()
                    showOrganizer = true
                }
            } label: {
                DoodleIcon(icon: .profile, color: MosaicTheme.indigo, lineWidth: 2.4)
                    .frame(width: 27, height: 27)
                    .frame(width: 48, height: 48)
                    .background(MosaicTheme.paper, in: Circle())
                    .overlay(Circle().stroke(MosaicTheme.border, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
            }
            .accessibilityLabel("Open organizer dashboard")
        }
        .overlay(alignment: .bottomLeading) {
            Label(store.backendState.isLive ? "Live Supabase" : "Demo cache", systemImage: store.backendState.isLive ? "bolt.horizontal.circle.fill" : "externaldrive.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(store.backendState.isLive ? MosaicTheme.sage : MosaicTheme.muted)
                .offset(y: 18)
        }
    }

    private var mosaicHero: some View {
        OrganicPanel(variant: .leaningLeft, tint: MosaicTheme.claySurface) {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(store.challenge.contributions.count) acts together")
                            .font(MosaicTheme.display(30, weight: .semibold))
                        Text("The final image stays sealed until reveal.")
                            .font(.footnote)
                            .foregroundStyle(MosaicTheme.muted)
                    }
                    Spacer(minLength: 4)
                    DoodleIcon(icon: .kintsugi, color: MosaicTheme.sage)
                        .frame(width: 30, height: 30)
                        .accessibilityLabel("Final mosaic sealed")
                }

                KinderArtworkView(selection: store.challenge.theme, phase: .sealed, cornerRadius: 24, showsTitle: true)
                    .frame(height: 230)

                MosaicBoard(contributions: Array(store.challenge.contributions.prefix(20)), columns: 5, tileSize: 50)
                    .frame(maxWidth: .infinity)

                ProgressView(value: progress)
                    .tint(MosaicTheme.persimmon)
                    .accessibilityLabel("Challenge progress")
                    .accessibilityValue("\(store.challenge.contributions.count) of \(store.challenge.goal) acts")
                HStack {
                    Label("\(store.challenge.goal - store.challenge.contributions.count) spaces", systemImage: "square.dashed")
                    Spacer()
                    Text(store.challenge.revealDate, style: .relative)
                }
                .font(MosaicTheme.caption(.semibold))
                .foregroundStyle(MosaicTheme.muted)
            }
        }
    }

    private var actionCard: some View {
        OrganicPanel(variant: .leaningRight) {
            VStack(alignment: .leading, spacing: 16) {
                MosaicSectionHeader(title: "Your next small act", eyebrow: "A little kindness", icon: .spark)

                HStack(spacing: 16) {
                    MosaicSticker(kind: .kindNote, size: 78)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Leave a kind note")
                            .font(MosaicTheme.display(24, weight: .semibold))
                        Text("Five minutes can brighten a whole day.")
                            .font(.subheadline)
                            .foregroundStyle(MosaicTheme.muted)
                    }
                }
                Button("Choose a mission") {
                    Task {
                        await store.openOrganizerSandbox()
                        showMissions = true
                    }
                }
                    .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.persimmon))
            }
        }
    }

    private var momentum: some View {
        VStack(alignment: .leading, spacing: 13) {
            MosaicSectionHeader(title: "Collective momentum", eyebrow: "Growing together", icon: .chain)
            HStack {
                MetricPill(icon: "link", text: "7 tile chains")
                MetricPill(icon: "sparkles", text: "2 revived")
            }
            Text("No rankings or points—just a growing record of showing up for one another.")
                .font(.footnote)
                .foregroundStyle(MosaicTheme.muted)
        }
        .padding(.horizontal, 4)
    }
}
