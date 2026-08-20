import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var isShowingLaunchOverlay: Bool

    init() {
#if DEBUG
        let previewRecap = ProcessInfo.processInfo.arguments.contains("-preview-recap")
            || ProcessInfo.processInfo.environment["MOSAIC_PREVIEW_RECAP"] == "1"
        let previewCamera = ProcessInfo.processInfo.arguments.contains("-preview-camera")
            || ProcessInfo.processInfo.environment["MOSAIC_PREVIEW_CAMERA"] == "1"
        let previewKinder = ProcessInfo.processInfo.arguments.contains("-preview-kinder")
            || ProcessInfo.processInfo.arguments.contains("-preview-kinder-artwork")
            || ProcessInfo.processInfo.environment["MOSAIC_PREVIEW_KINDER"] == "1"
        _isShowingLaunchOverlay = State(
            initialValue: !(previewRecap || previewCamera || previewKinder)
        )
#else
        _isShowingLaunchOverlay = State(initialValue: true)
#endif
    }

    var body: some View {
        ZStack {
            ZStack {
                MosaicTheme.canvas.ignoresSafeArea()

                if isKinderPreview {
                    KinderBlockCreationView(initialStep: isKinderArtworkPreview ? 2 : 1)
                } else if isCameraPreview, let mission = store.missions.first(where: { $0.evidence.contains(.photo) }) {
                    EvidenceCameraView(mission: mission) { _ in }
                } else if isRecapPreview {
                    RecapEditorView(challenge: store.challenge)
                } else if store.hasJoined {
                    MainTabView()
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else {
                    WelcomeView()
                        .transition(.opacity)
                }
            }
            .allowsHitTesting(!isShowingLaunchOverlay)
            .accessibilityHidden(isShowingLaunchOverlay)

            if isShowingLaunchOverlay {
                MosaicLaunchOverlay {
                    isShowingLaunchOverlay = false
                }
                .zIndex(10)
                .transition(.identity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.hasJoined)
        .tint(MosaicTheme.indigo)
        .sheet(isPresented: Binding(
            get: { store.isShowingOrganizerSetup },
            set: { store.isShowingOrganizerSetup = $0 }
        )) {
            OrganizationSetupView()
        }
        .sheet(isPresented: Binding(
            get: { store.isShowingPaywall },
            set: { store.isShowingPaywall = $0 }
        )) {
            MosaicPaywallView()
        }
        .sheet(isPresented: Binding(
            get: { store.isShowingInviteAcceptance },
            set: { store.isShowingInviteAcceptance = $0 }
        )) {
            WorkspaceInviteAcceptanceView()
        }
        .sheet(isPresented: Binding(
            get: { store.isShowingRecoveryPrompt },
            set: { store.isShowingRecoveryPrompt = $0 }
        )) {
            GuestRecoveryPromptView()
                .presentationDetents([.medium])
        }
        .onOpenURL { store.handle(url: $0) }
        .onReceive(NotificationCenter.default.publisher(for: .mosaicNotificationDeepLink)) { notification in
            guard let url = notification.object as? URL else { return }
            store.handle(url: url)
        }
    }

    private var isRecapPreview: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-preview-recap")
            || ProcessInfo.processInfo.environment["MOSAIC_PREVIEW_RECAP"] == "1"
#else
        false
#endif
    }

    private var isCameraPreview: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-preview-camera")
            || ProcessInfo.processInfo.environment["MOSAIC_PREVIEW_CAMERA"] == "1"
#else
        false
#endif
    }

    private var isKinderPreview: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-preview-kinder")
            || ProcessInfo.processInfo.arguments.contains("-preview-kinder-artwork")
            || ProcessInfo.processInfo.environment["MOSAIC_PREVIEW_KINDER"] == "1"
#else
        false
#endif
    }

    private var isKinderArtworkPreview: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-preview-kinder-artwork")
#else
        false
#endif
    }
}

private struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: AppTab
    @State private var routedSummary: ChallengeSummary?
    @State private var showRoutedMissions = false

    init() {
        var initial: AppTab = .home
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-preview-mosaics") { initial = .mosaics }
        if ProcessInfo.processInfo.arguments.contains("-preview-profile") { initial = .profile }
#endif
        _selection = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            tabLayer(.home) { NavigationStack { HomeView() } }
            tabLayer(.mosaics) { NavigationStack { MosaicsView() } }
            tabLayer(.profile) { NavigationStack { ProfileView() } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MosaicTabBar(
                selection: $selection,
                recapMode: store.challenge.revealedAt != nil || store.challenge.serverStatus == "revealed"
            ) {
                if store.challenge.revealedAt != nil || store.challenge.serverStatus == "revealed" {
                    store.openRecapEditor()
                } else {
                    store.openSharedCamera()
                }
            }
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .padding(.bottom, 8)
        }
        .sheet(item: $routedSummary) { summary in
            NavigationStack { EventDetailView(summary: summary) }
        }
        .fullScreenCover(isPresented: $showRoutedMissions) {
            NavigationStack { MissionLibraryView() }
        }
        .fullScreenCover(isPresented: Binding(get: { store.showSharedCamera }, set: { store.showSharedCamera = $0 })) {
            SharedRollCameraFlow()
        }
        .sheet(isPresented: Binding(get: { store.showSealedRoll }, set: { store.showSealedRoll = $0 })) {
            SealedRollView()
        }
        .fullScreenCover(isPresented: Binding(get: { store.showRecapEditor }, set: { store.showRecapEditor = $0 })) {
            RecapEditorView(challenge: store.challenge)
        }
        .onChange(of: store.pendingRoute, initial: true) { _, route in
            guard route != nil else { return }
            handlePendingRoute()
        }
    }

    private func handlePendingRoute() {
        guard let route = store.consumePendingRoute() else { return }
        switch route {
        case .missions(let challengeID):
            selection = .home
            showRoutedMissions = true
            if let challengeID { Task { await store.openChallenge(challengeID) } }
        case .challenge(let id):
            selection = .mosaics
            if let summary = store.summary(for: id) {
                routedSummary = summary
            } else {
                Task {
                    await store.openChallenge(id)
                    routedSummary = store.summary(for: id) ?? store.challenge.summary
                }
            }
        case .recap(let id):
            Task {
                await store.openChallenge(id)
                store.openRecapEditor()
            }
        case .camera(let challengeID):
            Task {
                if let challengeID { await store.openChallenge(challengeID) }
                store.openSharedCamera()
            }
        case .sealedRoll(let challengeID):
            Task {
                if let challengeID { await store.openChallenge(challengeID) }
                store.showSealedRoll = true
            }
        case .reveal(let id):
            selection = .mosaics
            Task {
                await store.openChallenge(id)
                store.showReveal = true
            }
        }
    }

    private func tabLayer<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(selection == tab ? 1 : 0)
            .allowsHitTesting(selection == tab)
            .accessibilityHidden(selection != tab)
            .zIndex(selection == tab ? 1 : 0)
    }
}

private enum AppTab: String, CaseIterable, Hashable {
    case home = "Home"
    case mosaics = "Mosaics"
    case profile = "You"

    var icon: MosaicIcon {
        switch self {
        case .home: .home
        case .mosaics: .mosaic
        case .profile: .profile
        }
    }
}

private struct MosaicTabBar: View {
    @Binding var selection: AppTab
    let recapMode: Bool
    let primaryAction: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.home)
            primaryButton
            tabButton(.mosaics)
            tabButton(.profile)
        }
        .padding(5)
        .background(MosaicTheme.paper.opacity(0.96), in: HandDrawnCapsule(inset: 0))
        .overlay { HandDrawnCapsule(inset: 1).stroke(Color.white.opacity(0.38), lineWidth: 1) }
        .overlay { HandDrawnCapsule(inset: 4).stroke(MosaicTheme.border.opacity(0.55), lineWidth: 0.8) }
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            if reduceMotion { selection = tab }
            else { withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) { selection = tab } }
        } label: {
            VStack(spacing: 3) {
                DoodleIcon(icon: tab.icon, color: selection == tab ? MosaicTheme.indigo : MosaicTheme.ink)
                    .frame(width: 25, height: 25)
                Text(tab.rawValue).font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selection == tab ? MosaicTheme.indigo : MosaicTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                if selection == tab { OrganicPanelShape(variant: .softRectangle).fill(MosaicTheme.indigo.opacity(0.11)).padding(2) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    private var primaryButton: some View {
        Button(action: primaryAction) {
            VStack(spacing: 2) {
                ZStack {
                    Circle().fill(MosaicTheme.paper).frame(width: 58, height: 58)
                        .overlay(Circle().stroke(recapMode ? MosaicTheme.gold : MosaicTheme.indigo, lineWidth: 5).padding(7))
                        .shadow(color: (recapMode ? MosaicTheme.gold : Color.black).opacity(0.28), radius: 10, y: 5)
                    Image(systemName: recapMode ? "sparkles" : "camera.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(recapMode ? MosaicTheme.gold : MosaicTheme.indigo)
                }
                Text(recapMode ? "Recap" : "Camera").font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .offset(y: -9)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recapMode ? "Open Golden Recap" : "Capture a moment")
        .accessibilityHint(recapMode ? "Opens the recap editor" : "Opens the active challenge camera")
    }
}
