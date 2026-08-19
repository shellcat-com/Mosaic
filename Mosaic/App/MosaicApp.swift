import SwiftUI

@main
struct MosaicApp: App {
    @State private var store = AppStore()

    init() {
        MosaicFontRegistrar.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { await store.bootstrap() }
        }
    }
}
