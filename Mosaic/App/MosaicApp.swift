import SwiftUI

@main
struct MosaicApp: App {
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
                    guard let token = notification.object as? String else { return }
                    Task { await store.registerDeviceToken(token) }
                }
        }
    }
}
