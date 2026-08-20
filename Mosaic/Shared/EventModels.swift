import Foundation

enum ChallengePhase: String, Codable, CaseIterable, Sendable {
    case upcoming
    case active
    case reveal
    case completed

    var title: String {
        switch self {
        case .upcoming: "Upcoming"
        case .active: "Active"
        case .reveal: "Reveal"
        case .completed: "Recap"
        }
    }
}

enum RecapAvailability: String, Codable, Sendable {
    case unavailable
    case processing
    case ready
}

struct ChallengeSummary: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var groupName: String
    var purpose: String
    var startAt: Date
    var revealAt: Date
    var revealedAt: Date?
    var serverStatus: String
    var scheduleRevision: Int
    var contributionCount: Int
    var goal: Int
    var recapAvailability: RecapAvailability
    var recapThumbnailFilename: String?
    var theme: ThemeSelection = .fallback

    init(
        id: UUID,
        name: String,
        groupName: String,
        purpose: String,
        startAt: Date,
        revealAt: Date,
        revealedAt: Date?,
        serverStatus: String,
        scheduleRevision: Int,
        contributionCount: Int,
        goal: Int,
        recapAvailability: RecapAvailability,
        recapThumbnailFilename: String?,
        theme: ThemeSelection = .fallback
    ) {
        self.id = id
        self.name = name
        self.groupName = groupName
        self.purpose = purpose
        self.startAt = startAt
        self.revealAt = revealAt
        self.revealedAt = revealedAt
        self.serverStatus = serverStatus
        self.scheduleRevision = scheduleRevision
        self.contributionCount = contributionCount
        self.goal = goal
        self.recapAvailability = recapAvailability
        self.recapThumbnailFilename = recapThumbnailFilename
        self.theme = theme
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, groupName, purpose, startAt, revealAt, revealedAt, serverStatus
        case scheduleRevision, contributionCount, goal, recapAvailability, recapThumbnailFilename, theme
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        groupName = try values.decode(String.self, forKey: .groupName)
        purpose = try values.decode(String.self, forKey: .purpose)
        startAt = try values.decode(Date.self, forKey: .startAt)
        revealAt = try values.decode(Date.self, forKey: .revealAt)
        revealedAt = try values.decodeIfPresent(Date.self, forKey: .revealedAt)
        serverStatus = try values.decode(String.self, forKey: .serverStatus)
        scheduleRevision = try values.decodeIfPresent(Int.self, forKey: .scheduleRevision) ?? 1
        contributionCount = try values.decodeIfPresent(Int.self, forKey: .contributionCount) ?? 0
        goal = try values.decode(Int.self, forKey: .goal)
        recapAvailability = try values.decodeIfPresent(RecapAvailability.self, forKey: .recapAvailability) ?? .unavailable
        recapThumbnailFilename = try values.decodeIfPresent(String.self, forKey: .recapThumbnailFilename)
        theme = try values.decodeIfPresent(ThemeSelection.self, forKey: .theme) ?? .fallback
    }

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(contributionCount) / Double(goal))
    }

    func phase(at date: Date = .now, calendar: Calendar = .current) -> ChallengePhase {
        if serverStatus == "archived" { return .completed }
        if let revealedAt {
            let revealWindowEnd = calendar.date(byAdding: .minute, value: 30, to: revealedAt) ?? revealedAt
            if date < revealWindowEnd, recapAvailability != .ready { return .reveal }
            return .completed
        }
        if serverStatus == "revealed" {
            let revealWindowEnd = calendar.date(byAdding: .minute, value: 30, to: revealAt) ?? revealAt
            return date < revealWindowEnd && recapAvailability != .ready ? .reveal : .completed
        }
        if date < startAt { return .upcoming }
        if date < revealAt { return .active }
        let revealWindowEnd = calendar.date(byAdding: .minute, value: 30, to: revealAt) ?? revealAt
        return date < revealWindowEnd && recapAvailability != .ready ? .reveal : .completed
    }

    var deepLink: URL? {
        URL(string: "mosaic://challenge/\(id.uuidString.lowercased())")
    }

    var recapDeepLink: URL? {
        URL(string: "mosaic://recap/\(id.uuidString.lowercased())")
    }
}

struct NotificationPreferences: Codable, Hashable, Sendable {
    var challengeStart = true
    var revealDayBefore = true
    var revealHourBefore = true
    var revealNow = true
    var recapReady = true
    var liveActivity = false

    static let helpful = NotificationPreferences()

    var remindersEnabled: Bool {
        challengeStart || revealDayBefore || revealHourBefore || revealNow || recapReady
    }
}

struct ScheduledEventReminder: Equatable, Sendable {
    let kind: String
    let date: Date
    let route: String

    func identifier(for summary: ChallengeSummary) -> String {
        "mosaic.\(summary.id.uuidString.lowercased()).\(kind).v\(summary.scheduleRevision)"
    }
}

enum EventReminderPlan {
    static func make(
        summary: ChallengeSummary,
        preferences: NotificationPreferences,
        calendar: Calendar = .current
    ) -> [ScheduledEventReminder] {
        var reminders: [ScheduledEventReminder] = []
        if preferences.challengeStart {
            reminders.append(.init(kind: "start", date: summary.startAt, route: "challenge"))
        }
        if preferences.revealDayBefore {
            reminders.append(.init(
                kind: "reveal-day",
                date: calendar.date(byAdding: .hour, value: -24, to: summary.revealAt) ?? summary.revealAt,
                route: "challenge"
            ))
        }
        if preferences.revealHourBefore {
            reminders.append(.init(
                kind: "reveal-hour",
                date: calendar.date(byAdding: .hour, value: -1, to: summary.revealAt) ?? summary.revealAt,
                route: "challenge"
            ))
        }
        if preferences.revealNow {
            reminders.append(.init(kind: "reveal-now", date: summary.revealAt, route: "reveal"))
        }
        if preferences.liveActivity {
            reminders.append(.init(
                kind: "follow-live",
                date: calendar.date(byAdding: .minute, value: -30, to: summary.revealAt) ?? summary.revealAt,
                route: "challenge"
            ))
        }
        return reminders
    }
}

enum EventRoute: Equatable, Sendable {
    case challenge(UUID)
    case reveal(UUID)
    case recap(UUID)
    case camera(UUID?)
    case sealedRoll(UUID?)
    case missions(UUID?)
}

enum EventRouteParser {
    static func parse(_ url: URL) -> EventRoute? {
        guard url.scheme?.lowercased() == "mosaic" else { return nil }
        let kind = url.host?.lowercased()
        let components = url.pathComponents.filter { $0 != "/" }
        let id = components.first.flatMap(UUID.init(uuidString:))
        switch kind {
        case "challenge": return id.map(EventRoute.challenge)
        case "reveal": return id.map(EventRoute.reveal)
        case "recap": return id.map(EventRoute.recap)
        case "camera": return .camera(id)
        case "roll": return .sealedRoll(id)
        case "missions": return .missions(id)
        default: return nil
        }
    }
}
