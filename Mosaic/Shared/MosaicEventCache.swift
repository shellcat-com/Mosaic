import Foundation

enum MosaicEventCache {
    static let appGroupIdentifier = "group.com.biswaskhatiwada.mosaicapp"
    private static let summariesKey = "event-summaries-v1"
    private static let preferencesKey = "event-notification-preferences-v1"
    private static let preferredWidgetKey = "preferred-widget-challenge-v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func loadSummaries() -> [ChallengeSummary] {
        guard let data = defaults.data(forKey: summariesKey) else { return [] }
        return (try? decoder.decode([ChallengeSummary].self, from: data)) ?? []
    }

    static func saveSummaries(_ summaries: [ChallengeSummary]) {
        guard let data = try? encoder.encode(summaries) else { return }
        defaults.set(data, forKey: summariesKey)
    }

    static func loadPreferences() -> [UUID: NotificationPreferences] {
        guard let data = defaults.data(forKey: preferencesKey),
              let stored = try? decoder.decode([String: NotificationPreferences].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
            UUID(uuidString: key).map { ($0, value) }
        })
    }

    static func savePreferences(_ preferences: [UUID: NotificationPreferences]) {
        let stored = Dictionary(uniqueKeysWithValues: preferences.map { ($0.key.uuidString, $0.value) })
        guard let data = try? encoder.encode(stored) else { return }
        defaults.set(data, forKey: preferencesKey)
    }

    static var preferredWidgetChallengeID: UUID? {
        get { defaults.string(forKey: preferredWidgetKey).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: preferredWidgetKey) }
    }

    static func automaticSummary(from summaries: [ChallengeSummary], at date: Date = .now) -> ChallengeSummary? {
        if let preferredWidgetChallengeID,
           let preferred = summaries.first(where: { $0.id == preferredWidgetChallengeID }) {
            return preferred
        }
        let actionable = summaries
            .filter { $0.phase(at: date) != .completed }
            .sorted { lhs, rhs in
                let leftDate = lhs.phase(at: date) == .upcoming ? lhs.startAt : lhs.revealAt
                let rightDate = rhs.phase(at: date) == .upcoming ? rhs.startAt : rhs.revealAt
                return leftDate < rightDate
            }
        if let first = actionable.first { return first }
        return summaries
            .filter { $0.phase(at: date) == .completed }
            .sorted { ($0.revealedAt ?? $0.revealAt) > ($1.revealedAt ?? $1.revealAt) }
            .first
    }

    static func thumbnailURL(for summary: ChallengeSummary) -> URL? {
        guard let filename = summary.recapThumbnailFilename,
              let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
              )
        else { return nil }
        return container.appendingPathComponent(filename, isDirectory: false)
    }

    @discardableResult
    static func storeThumbnail(_ data: Data, remotePath: String) throws -> String {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { throw CocoaError(.fileNoSuchFile) }
        let remoteName = URL(fileURLWithPath: remotePath).lastPathComponent
        let filename = "recap-\(remoteName)"
        try data.write(to: container.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
