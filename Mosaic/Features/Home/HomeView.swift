import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var showMissions = false
    @State private var showOrganizer = false

    private var progress: Double {
        Double(store.challenge.contributions.count) / Double(store.challenge.goal)
    }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 26) {
                header
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
        .onChange(of: showOrganizer) { _, isPresented in
            if !isPresented { Task { await store.returnToShowcase() } }
        }
        .fullScreenCover(isPresented: Binding(get: { store.showReveal }, set: { store.showReveal = $0 })) {
            RevealView()
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
