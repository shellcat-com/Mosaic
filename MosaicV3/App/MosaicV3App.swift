import SwiftUI

@main
struct MosaicV3App: App {
    @State private var model: MosaicAppModel
    #if DEBUG
    private let showcaseScreen: MosaicShowcaseScreen?
    #endif

    init() {
        MosaicFontRegistrar.register()
        #if DEBUG
        let screen = ProcessInfo.processInfo.environment["MOSAIC_SHOWCASE_SCREEN"].flatMap(MosaicShowcaseScreen.init(rawValue:))
        showcaseScreen = screen
        _model = State(initialValue: screen == nil ? MosaicAppModel() : MosaicShowcaseFixtures.makeModel(screen: screen))
        #else
        _model = State(initialValue: MosaicAppModel())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let showcaseScreen, showcaseScreen != .root {
                MosaicShowcaseRoot(screen: showcaseScreen).environment(model)
            } else {
                productionRoot
            }
            #else
            productionRoot
            #endif
        }
    }

    private var productionRoot: some View {
        MosaicRootView()
            .environment(model)
            .task { await model.bootstrap() }
            .onOpenURL { model.handle(url: $0) }
    }
}
