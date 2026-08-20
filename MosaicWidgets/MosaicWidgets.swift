import AppIntents
import SwiftUI
import UIKit
import WidgetKit

struct WidgetChallengeEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Mosaic Challenge")
    static let defaultQuery = WidgetChallengeQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct WidgetChallengeQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetChallengeEntity] {
        MosaicEventCache.loadSummaries()
            .filter { identifiers.contains($0.id.uuidString) }
            .map { WidgetChallengeEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func suggestedEntities() async throws -> [WidgetChallengeEntity] {
        MosaicEventCache.loadSummaries().map {
            WidgetChallengeEntity(id: $0.id.uuidString, name: $0.name)
        }
    }
}

struct MosaicWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose a Mosaic"
    static let description = IntentDescription("Automatically show what is next, or pin one challenge.")

    @Parameter(title: "Pinned challenge")
    var challenge: WidgetChallengeEntity?
}

struct MosaicWidgetEntry: TimelineEntry {
    let date: Date
    let summary: ChallengeSummary?
}

struct MosaicTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MosaicWidgetEntry {
        MosaicWidgetEntry(date: .now, summary: sampleSummary)
    }

    func snapshot(for configuration: MosaicWidgetIntent, in context: Context) async -> MosaicWidgetEntry {
        MosaicWidgetEntry(date: .now, summary: resolve(configuration))
    }

    func timeline(for configuration: MosaicWidgetIntent, in context: Context) async -> Timeline<MosaicWidgetEntry> {
        let now = Date.now
        let summary = resolve(configuration)
        let entry = MosaicWidgetEntry(date: now, summary: summary)
        let boundaries = [summary?.startAt, summary?.revealAt]
            .compactMap { $0 }
            .filter { $0 > now }
        let refresh = boundaries.min() ?? now.addingTimeInterval(15 * 60)
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func resolve(_ configuration: MosaicWidgetIntent) -> ChallengeSummary? {
        let summaries = MosaicEventCache.loadSummaries()
        if let id = configuration.challenge?.id,
           let uuid = UUID(uuidString: id),
           let pinned = summaries.first(where: { $0.id == uuid }) {
            return pinned
        }
        return MosaicEventCache.automaticSummary(from: summaries)
    }

    private var sampleSummary: ChallengeSummary {
        ChallengeSummary(
            id: UUID(),
            name: "A Kinder Block",
            groupName: "Mosaic Community",
            purpose: "Small acts, one shared artwork.",
            startAt: .now.addingTimeInterval(-86_400),
            revealAt: .now.addingTimeInterval(3_600),
            revealedAt: nil,
            serverStatus: "active",
            scheduleRevision: 1,
            contributionCount: 18,
            goal: 40,
            recapAvailability: .unavailable,
            recapThumbnailFilename: nil
        )
    }
}

struct MosaicWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MosaicWidgetEntry

    var body: some View {
        if let summary = entry.summary {
            content(summary)
                .widgetURL(summary.phase(at: entry.date) == .completed ? summary.recapDeepLink : summary.deepLink)
                .containerBackground(for: .widget) { Color.mosaicCanvas }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "square.grid.3x3.fill").foregroundStyle(Color.mosaicIndigo)
                Text("Open Mosaic")
                    .font(.headline)
                Text("Join a challenge to keep its reveal close.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .containerBackground(for: .widget) { Color.mosaicCanvas }
        }
    }

    @ViewBuilder
    private func content(_ summary: ChallengeSummary) -> some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular(summary)
        case .accessoryRectangular:
            accessoryRectangular(summary)
        default:
            homeWidget(summary)
        }
    }

    @ViewBuilder
    private func homeWidget(_ summary: ChallengeSummary) -> some View {
        if summary.phase(at: entry.date) == .completed,
           let url = MosaicEventCache.thumbnailURL(for: summary),
           let image = UIImage(contentsOfFile: url.path) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .accessibilityHidden(true)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.name).font(.headline).lineLimit(1)
                    Label("Watch recap", systemImage: "play.fill").font(.caption.bold())
                }
                .foregroundStyle(.white)
                .padding(12)
            }
        } else {
            HStack(spacing: 13) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(summary.phase(at: entry.date).title.uppercased())
                        .font(.caption2.bold())
                        .tracking(0.7)
                        .foregroundStyle(phaseColor(summary))
                    Text(summary.name)
                        .font(.headline)
                        .lineLimit(2)
                    phaseDetail(summary)
                    ProgressView(value: summary.progress)
                        .tint(phaseColor(summary))
                }
                if family == .systemMedium {
                    MosaicMiniature(progress: summary.progress, tint: phaseColor(summary))
                        .frame(width: 90, height: 90)
                }
            }
        }
    }

    private func accessoryCircular(_ summary: ChallengeSummary) -> some View {
        Gauge(value: summary.progress) {
            Image(systemName: summary.phase(at: entry.date) == .completed ? "play.fill" : "square.grid.3x3.fill")
        } currentValueLabel: {
            Text("\(summary.contributionCount)")
                .font(.caption2.bold())
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private func accessoryRectangular(_ summary: ChallengeSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.name).font(.headline).lineLimit(1)
            if summary.phase(at: entry.date) == .completed {
                Label("Watch recap", systemImage: "play.fill")
            } else {
                Text(summary.revealAt, style: .relative)
            }
        }
        .font(.caption)
    }

    @ViewBuilder
    private func phaseDetail(_ summary: ChallengeSummary) -> some View {
        switch summary.phase(at: entry.date) {
        case .upcoming:
            Text("Begins \(summary.startAt, style: .relative)")
        case .active:
            Text("Reveals \(summary.revealAt, style: .relative)")
        case .reveal:
            Label("The mosaic is ready", systemImage: "sparkles")
        case .completed:
            Label("Watch recap", systemImage: "play.fill")
        }
    }

    private func phaseColor(_ summary: ChallengeSummary) -> Color {
        switch summary.phase(at: entry.date) {
        case .upcoming: .mosaicSky
        case .active: .mosaicSage
        case .reveal: .mosaicPersimmon
        case .completed: .mosaicIndigo
        }
    }
}

private struct MosaicMiniature: View {
    let progress: Double
    let tint: Color

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4), spacing: 3) {
            ForEach(0..<16, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Double(index) / 16 < progress ? tint.opacity(0.82) : Color.secondary.opacity(0.12))
                    .rotationEffect(.degrees(index.isMultiple(of: 3) ? 2 : -1))
            }
        }
        .accessibilityHidden(true)
    }
}

struct MosaicHomeWidget: Widget {
    let kind = "MosaicEventWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MosaicWidgetIntent.self, provider: MosaicTimelineProvider()) {
            MosaicWidgetView(entry: $0)
        }
        .configurationDisplayName("Mosaic Event")
        .description("Follow a challenge from countdown through recap.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private extension Color {
    static let mosaicCanvas = Color(red: 0.984, green: 0.973, blue: 0.945)
    static let mosaicIndigo = Color(red: 0.353, green: 0.278, blue: 0.949)
    static let mosaicPersimmon = Color(red: 0.961, green: 0.431, blue: 0.243)
    static let mosaicSage = Color(red: 0.49, green: 0.604, blue: 0.514)
    static let mosaicSky = Color(red: 0.494, green: 0.718, blue: 0.804)
}
