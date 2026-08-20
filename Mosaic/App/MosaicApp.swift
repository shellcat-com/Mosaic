import SwiftUI

@main
struct MosaicApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(MosaicAppDelegate.self) private var appDelegate
    @State private var store = AppStore()

    init() {
        MosaicFontRegistrar.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task {
#if DEBUG
                    guard MarketingPreviewScene.current == nil else { return }
#endif
                    await store.bootstrap()
                }
                .task {
#if DEBUG
                    guard MarketingPreviewScene.current == nil else { return }
#endif
                    await store.monitorPendingMomentUploads()
                }
                .onReceive(NotificationCenter.default.publisher(for: .mosaicRemoteDeviceToken)) { notification in
                    guard MosaicBuildConfiguration.remotePushEnabled else { return }
                    guard let token = notification.object as? String else { return }
                    Task { await store.registerDeviceToken(token) }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active, !store.backendState.isLive else { return }
                    Task { await store.bootstrap() }
                }
        }
    }
}
