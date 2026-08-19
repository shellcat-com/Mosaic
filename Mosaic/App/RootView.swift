import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var isShowingLaunchOverlay = true

    var body: some View {
        ZStack {
            ZStack {
                MosaicTheme.canvas.ignoresSafeArea()

                if store.hasJoined {
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
    }
}

private struct MainTabView: View {
    @State private var selection: AppTab

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
            MosaicTabBar(selection: $selection)
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .padding(.bottom, 8)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    if reduceMotion {
                        selection = tab
                    } else {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) { selection = tab }
                    }
                } label: {
                    VStack(spacing: 3) {
                        DoodleIcon(icon: tab.icon, color: selection == tab ? MosaicTheme.indigo : MosaicTheme.ink)
                            .frame(width: 25, height: 25)
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(selection == tab ? MosaicTheme.indigo : MosaicTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background {
                        if selection == tab {
                            OrganicPanelShape(variant: .softRectangle)
                                .fill(MosaicTheme.indigo.opacity(0.11))
                                .padding(2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(5)
        .background(MosaicTheme.paper.opacity(0.96), in: HandDrawnCapsule(inset: 0))
        .overlay { HandDrawnCapsule(inset: 1).stroke(Color.white.opacity(0.38), lineWidth: 1) }
        .overlay { HandDrawnCapsule(inset: 4).stroke(MosaicTheme.border.opacity(0.55), lineWidth: 0.8) }
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
    }
}
