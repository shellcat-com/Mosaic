import SwiftUI
import WidgetKit

@main
struct MosaicWidgetBundle: WidgetBundle {
    var body: some Widget {
        MosaicHomeWidget()
        MosaicLiveActivityWidget()
    }
}
