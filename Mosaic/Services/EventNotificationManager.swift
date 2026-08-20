import Foundation
import UIKit
import UserNotifications

enum NotificationPermissionState: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
}

@MainActor
final class EventNotificationManager {
    static let shared = EventNotificationManager()
    private let center = UNUserNotificationCenter.current()

    func permissionState() async -> NotificationPermissionState {
        let settings = await center.notificationSettings()
        return switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .allowed
        case .denied: .denied
        default: .notDetermined
        }
    }

    func requestPermissionAndSchedule(
        summary: ChallengeSummary,
        preferences: NotificationPreferences
    ) async throws -> NotificationPermissionState {
        var state = await permissionState()
        if state == .notDetermined {
            let allowed = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            state = allowed ? .allowed : .denied
        }
        guard state == .allowed else { return state }
        if MosaicBuildConfiguration.remotePushEnabled {
            UIApplication.shared.registerForRemoteNotifications()
        }
        try await schedule(summary: summary, preferences: preferences)
        return state
    }

    func schedule(summary: ChallengeSummary, preferences: NotificationPreferences, now: Date = .now) async throws {
        await removePending(for: summary.id)
        guard preferences.remindersEnabled else { return }
        for reminder in EventReminderPlan.make(summary: summary, preferences: preferences) {
            let copy = copy(for: reminder.kind, summary: summary)
            try await add(
                reminder: reminder,
                summary: summary,
                title: copy.title,
                body: copy.body,
                now: now
            )
        }
    }

    func notifyRecapReady(for summary: ChallengeSummary) async throws {
        guard await permissionState() == .allowed else { return }
        let content = content(
            title: "Your Mosaic recap is ready",
            body: "Keep the story of \(summary.name) close.",
            summary: summary,
            route: "recap"
        )
        let request = UNNotificationRequest(
            identifier: identifier(kind: "recap-ready", summary: summary),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try await center.add(request)
    }

    func removePending(for challengeID: UUID) async {
        let prefix = "mosaic.\(challengeID.uuidString.lowercased())."
        let requests = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
        )
    }

    private func add(
        reminder: ScheduledEventReminder,
        summary: ChallengeSummary,
        title: String,
        body: String,
        now: Date
    ) async throws {
        guard reminder.date > now else { return }
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
                from: reminder.date
            ),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: reminder.identifier(for: summary),
            content: content(title: title, body: body, summary: summary, route: reminder.route),
            trigger: trigger
        )
        try await center.add(request)
    }

    private func identifier(kind: String, summary: ChallengeSummary) -> String {
        "mosaic.\(summary.id.uuidString.lowercased()).\(kind).v\(summary.scheduleRevision)"
    }

    private func copy(for kind: String, summary: ChallengeSummary) -> (title: String, body: String) {
        switch kind {
        case "start": return ("\(summary.name) begins today", "Open Mosaic and choose a small act to begin.")
        case "reveal-day": return ("The mosaic reveals tomorrow", "\(summary.name) opens in 24 hours.")
        case "reveal-hour": return ("Reveal in one hour", "Come back to see every act become one artwork.")
        case "reveal-now": return ("The mosaic is ready", "Open the reveal for \(summary.name).")
        default: return ("Follow the reveal live", "Open Mosaic to place \(summary.name) on your Lock Screen.")
        }
    }

    private func content(
        title: String,
        body: String,
        summary: ChallengeSummary,
        route: String
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "challenge.\(summary.id.uuidString.lowercased())"
        content.userInfo = [
            "deep_link": "mosaic://\(route)/\(summary.id.uuidString.lowercased())"
        ]
        return content
    }
}
