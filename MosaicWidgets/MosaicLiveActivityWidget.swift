import ActivityKit
import SwiftUI
import WidgetKit

struct MosaicLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MosaicActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: context.state.recapReady ? "play.rectangle.fill" : "square.grid.3x3.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.353, green: 0.278, blue: 0.949))
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.challengeName)
                        .font(.headline)
                    LiveActivityStatus(state: context.state)
                    ProgressView(
                        value: Double(context.state.contributionCount),
                        total: Double(max(context.state.goal, 1))
                    )
                    .tint(Color(red: 0.961, green: 0.431, blue: 0.243))
                }
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.984, green: 0.973, blue: 0.945))
            .activitySystemActionForegroundColor(.primary)
            .widgetURL(URL(string: "mosaic://reveal/\(context.attributes.challengeID.uuidString.lowercased())"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "square.grid.3x3.fill")
                        .foregroundStyle(.indigo)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.contributionCount)/\(context.state.goal)")
                        .font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.challengeName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityStatus(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(.indigo)
            } compactTrailing: {
                Text("\(context.state.contributionCount)")
                    .font(.caption2.bold())
            } minimal: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
            }
            .widgetURL(URL(string: "mosaic://reveal/\(context.attributes.challengeID.uuidString.lowercased())"))
            .keylineTint(.orange)
        }
    }
}

private struct LiveActivityStatus: View {
    let state: MosaicActivityAttributes.ContentState

    var body: some View {
        if state.recapReady {
            Label("Recap ready", systemImage: "play.fill")
                .font(.caption.bold())
        } else if state.phase == .reveal {
            Label("The reveal is open", systemImage: "sparkles")
                .font(.caption.bold())
        } else {
            Text(state.revealAt, style: .timer)
                .font(.caption.bold().monospacedDigit())
        }
    }
}
