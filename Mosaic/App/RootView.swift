import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var isShowingLaunchOverlay: Bool

    init() {
#if DEBUG
        let marketingPreview = MarketingPreviewScene.current != nil
        let previewRecap = ProcessInfo.processInfo.arguments.contains("-preview-recap")
            || ProcessInfo.processInfo.environment["MOSAIC_PREVIEW_RECAP"] == "1"
        let previewCamera = ProcessInfo.processInfo.arguments.contains("-preview-camera")
            || ProcessInfo.processInfo.environment["MOSAIC_PREVIEW_CAMERA"] == "1"
        let previewKinder = ProcessInfo.processInfo.arguments.contains("-preview-kinder")
            || ProcessInfo.processInfo.arguments.contains("-preview-kinder-artwork")
            || ProcessInfo.processInfo.environment["MOSAIC_PREVIEW_KINDER"] == "1"
        _isShowingLaunchOverlay = State(
            initialValue: !(marketingPreview || previewRecap || previewCamera || previewKinder)
        )
#else
        _isShowingLaunchOverlay = State(initialValue: true)
#endif
    }

    var body: some View {
#if DEBUG
        if let marketingPreview = MarketingPreviewScene.current {
            MarketingPreviewRootView(scene: marketingPreview)
                .preferredColorScheme(.light)
        } else {
            appRoot
        }
#else
        appRoot
#endif
    }

    private var appRoot: some View {
        ZStack {
            ZStack {
                MosaicTheme.canvas.ignoresSafeArea()

                if isKinderPreview {
                    KinderBlockCreationView(initialStep: isKinderArtworkPreview ? 2 : 1)
                } else if isCameraPreview, let mission = store.missions.first(where: { $0.evidence.contains(.photo) }) {
                    EvidenceCameraView(mission: mission) { _ in }
                } else if isRecapPreview {
                    RecapEditorView(challenge: store.challenge)
                } else if store.entryState == .main {
                    MainTabView()
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else if store.entryState == .launching {
                    ProgressView("Preparing Mosaic…")
                        .font(MosaicTheme.body(.medium))
                        .tint(MosaicTheme.indigo)
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
        .animation(.easeInOut(duration: 0.35), value: store.entryState)
        .tint(MosaicTheme.indigo)
        .sheet(isPresented: Binding(
            get: { store.isShowingOrganizerSetup },
            set: { store.isShowingOrganizerSetup = $0 }
        )) {
            OrganizationSetupView()
        }
        .sheet(isPresented: Binding(
            get: { MosaicBuildConfiguration.billingEnabled && store.isShowingPaywall },
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

#if DEBUG
enum MarketingPreviewScene: String, CaseIterable {
    case home
    case folder
    case add
    case capture
    case memory
    case mission
    case privacy
    case placement
    case organizer
    case reveal

    static var current: MarketingPreviewScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-marketing-preview") else { return nil }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return MarketingPreviewScene(rawValue: arguments[valueIndex].lowercased())
    }
}

private struct MarketingPreviewRootView: View {
    let scene: MarketingPreviewScene
    @Environment(AppStore.self) private var store
    @State private var router = MosaicRouter()

    private var mission: Mission {
        store.missions.first ?? Mission(
            title: "Leave a kind note",
            detail: "Brighten someone’s day with a few kind words.",
            category: .encouragement,
            minutes: 5,
            effort: "Easy",
            evidence: [.reflection, .photo]
        )
    }

    private var contribution: TileContribution {
        TileContribution(
            id: UUID(uuidString: "40000000-0000-4000-8000-000000000001")!,
            mission: mission,
            emotion: .caring,
            evidence: .reflection,
            contributor: "Maya",
            sharedMemory: true,
            isRevived: false,
            status: .verified,
            tilePosition: 24,
            participantID: UUID(uuidString: "40000000-0000-4000-8000-000000000002")!,
            createdAt: Date(timeIntervalSince1970: 1_799_971_200),
            memory: ContributionMemory(
                kind: .reflection,
                note: "A small note changed the tone of the whole afternoon.",
                recapConsent: true,
                attributionAllowed: true
            )
        )
    }

    @ViewBuilder
    private var preview: some View {
        switch scene {
        case .home:
            MainTabView()
        case .folder:
            NavigationStack {
                KindnessRollFolderView(summary: store.challenge.summary)
            }
        case .add:
            MainTabView(initialSelection: .camera)
        case .capture:
            SharedRollCameraFlow(startsInViewfinder: true)
        case .memory:
            SharedRollCameraFlow()
        case .mission:
            NavigationStack {
                MissionDetailView(mission: mission)
            }
        case .privacy:
            NavigationStack {
                PrivacyReviewView(
                    mission: mission,
                    method: .reflection,
                    reflection: "I left a note for someone who needed a little encouragement.",
                    photoData: nil,
                    videoDuration: nil
                )
            }
        case .placement:
            NavigationStack {
                TilePlacementView(contribution: contribution)
            }
        case .organizer:
            NavigationStack {
                OrganizerDashboardView()
            }
        case .reveal:
            RevealView()
        }
    }

    var body: some View {
        preview
            .environment(router)
            .transaction { transaction in
                transaction.animation = nil
            }
    }
}
#endif

private struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @State private var router: MosaicRouter

    init(initialSelection: AppTab = .groups) {
        let router = MosaicRouter()
        router.selection = initialSelection
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-preview-mosaics") { router.selection = .groups }
        if ProcessInfo.processInfo.arguments.contains("-preview-profile") { router.selection = .profile }
#endif
        _router = State(initialValue: router)
    }

    var body: some View {
        @Bindable var router = router
        ZStack {
            tabLayer(.groups) { NavigationStack { GroupsLibraryView() } }
            tabLayer(.camera) { NavigationStack { KindnessCameraTabView() } }
            tabLayer(.profile) { NavigationStack { ProfileView() } }
        }
        .environment(router)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MosaicTabBar(selection: $router.selection)
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .padding(.bottom, 8)
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .event(let summary):
                NavigationStack { EventDetailView(summary: summary) }
                    .environment(router)
            case .memories:
                SealedRollView()
                    .environment(router)
            case .organizer(let returnChallengeID):
                NavigationStack { OrganizerDashboardView() }
                    .environment(router)
                    .onDisappear {
                        guard let returnChallengeID else { return }
                        Task { await store.openChallenge(returnChallengeID) }
                    }
            }
        }
        .fullScreenCover(item: $router.cover) { cover in
            coverView(for: cover)
                .environment(router)
        }
        .onChange(of: store.pendingRoute, initial: true) { _, route in
            guard route != nil else { return }
            handlePendingRoute()
        }
        .onChange(of: store.showSharedCamera, initial: true) { _, visible in
            guard visible else { return }
            store.showSharedCamera = false
            router.showMemoryComposer()
        }
        .onChange(of: store.showSealedRoll, initial: true) { _, visible in
            guard visible else { return }
            store.showSealedRoll = false
            router.showMemories()
        }
        .onChange(of: store.showRecapEditor, initial: true) { _, visible in
            guard visible else { return }
            store.showRecapEditor = false
            router.showRecap()
        }
        .onChange(of: store.showReveal, initial: true) { _, visible in
            guard visible else { return }
            store.showReveal = false
            router.showReveal()
        }
    }

    @ViewBuilder
    private func coverView(for cover: MosaicCover) -> some View {
        switch cover {
        case .missions(let challengeID):
            ChallengeCoverLoader(challengeID: challengeID) { _ in
                NavigationStack { MissionLibraryView() }
            }
        case .memory(let challengeID):
            ChallengeCoverLoader(challengeID: challengeID) { _ in
                SharedRollCameraFlow()
            }
        case .reveal(let challengeID):
            ChallengeCoverLoader(challengeID: challengeID) { _ in
                RevealView()
            }
        case .recap(let challengeID):
            ChallengeCoverLoader(challengeID: challengeID) { challenge in
                RecapEditorView(challenge: challenge)
            }
        }
    }

    private func handlePendingRoute() {
        guard let route = store.consumePendingRoute() else { return }
        switch route {
        case .join(let code):
            Task { await store.resolveInvitation(code: code) }
        case .missions(let challengeID):
            router.selection = .camera
            router.showMissions(for: challengeID)
        case .challenge(let id):
            router.selection = .groups
            if let summary = store.summary(for: id) {
                router.showEvent(summary)
            } else {
                Task {
                    await store.openChallenge(id)
                    router.showEvent(store.summary(for: id) ?? store.challenge.summary)
                }
            }
        case .recap(let id):
            router.selection = .groups
            router.showRecap(for: id)
        case .camera(let challengeID):
            router.selection = .camera
            router.showMemoryComposer(for: challengeID)
        case .sealedRoll(let challengeID):
            Task {
                if let challengeID { await store.openChallenge(challengeID) }
                router.showMemories()
            }
        case .reveal(let id):
            router.selection = .groups
            router.showReveal(for: id)
        }
    }

    private func tabLayer<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .id("\(tab.rawValue)-\(router.navigationGeneration)")
            .opacity(router.selection == tab ? 1 : 0)
            .allowsHitTesting(router.selection == tab)
            .accessibilityHidden(router.selection != tab)
            .zIndex(router.selection == tab ? 1 : 0)
    }
}

private struct ChallengeCoverLoader<Content: View>: View {
    let challengeID: UUID?
    @ViewBuilder let content: (KindnessChallenge) -> Content

    @Environment(AppStore.self) private var store
    @State private var isReady = false

    var body: some View {
        Group {
            if isReady {
                content(store.challenge)
            } else {
                ProgressView("Opening Mosaic…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MosaicTheme.canvas)
            }
        }
        .task(id: challengeID) {
            if let challengeID, store.challenge.id != challengeID {
                await store.openChallenge(challengeID)
            }
            isReady = true
        }
    }
}

private struct MosaicTabBar: View {
    @Binding var selection: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var isCamera: Bool { selection == .camera }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(5)
        .background(isCamera ? MosaicTheme.ink.opacity(0.96) : MosaicTheme.paper.opacity(0.96), in: HandDrawnCapsule(inset: 0))
        .overlay { HandDrawnCapsule(inset: 1).stroke(Color.white.opacity(isCamera ? 0.16 : 0.38), lineWidth: 1) }
        .overlay { HandDrawnCapsule(inset: 4).stroke(isCamera ? Color.white.opacity(0.1) : MosaicTheme.border.opacity(0.55), lineWidth: 0.8) }
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            if reduceMotion { selection = tab }
            else { withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) { selection = tab } }
        } label: {
            VStack(spacing: 3) {
                DoodleIcon(
                    icon: tab.icon,
                    color: isCamera
                        ? (selection == tab ? MosaicTheme.gold : .white.opacity(0.72))
                        : (selection == tab ? MosaicTheme.indigo : MosaicTheme.ink)
                )
                    .frame(width: 25, height: 25)
                Text(tab.rawValue).font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isCamera
                ? (selection == tab ? MosaicTheme.gold : .white.opacity(0.72))
                : (selection == tab ? MosaicTheme.indigo : MosaicTheme.ink))
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                if selection == tab {
                    OrganicPanelShape(variant: .softRectangle)
                        .fill(isCamera ? Color.white.opacity(0.08) : MosaicTheme.indigo.opacity(0.11))
                        .padding(2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }
}
