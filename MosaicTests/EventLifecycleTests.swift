import Foundation
import Testing
@testable import Mosaic

@Suite(.serialized)
struct EventLifecycleTests {
    @Test func phaseTransitionsAtEveryBoundaryWithoutNetworkRefresh() {
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        let reveal = start.addingTimeInterval(3_600)
        let summary = makeSummary(start: start, reveal: reveal)

        #expect(summary.phase(at: start.addingTimeInterval(-1)) == .upcoming)
        #expect(summary.phase(at: start) == .active)
        #expect(summary.phase(at: reveal) == .reveal)
        #expect(summary.phase(at: reveal.addingTimeInterval(1_799)) == .reveal)
        #expect(summary.phase(at: reveal.addingTimeInterval(1_800)) == .completed)
    }

    @Test func readyRecapEndsRevealWindowImmediately() {
        let reveal = Date(timeIntervalSince1970: 2_000_000_000)
        var summary = makeSummary(start: reveal.addingTimeInterval(-3_600), reveal: reveal)
        summary.serverStatus = "revealed"
        summary.revealedAt = reveal
        summary.recapAvailability = .ready
        #expect(summary.phase(at: reveal.addingTimeInterval(1)) == .completed)
    }

    @Test func reminderPlanUsesStableRevisionedIdentifiersAndDSTSafeOffsets() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        let reveal = try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone, year: 2026, month: 3, day: 8, hour: 10
        )))
        let summary = makeSummary(start: reveal.addingTimeInterval(-172_800), reveal: reveal, revision: 7)
        let reminders = EventReminderPlan.make(summary: summary, preferences: .helpful, calendar: calendar)

        #expect(reminders.map(\.kind) == ["start", "reveal-day", "reveal-hour", "reveal-now"])
        #expect(reveal.timeIntervalSince(try #require(reminders.first { $0.kind == "reveal-day" }).date) == 86_400)
        #expect(reveal.timeIntervalSince(try #require(reminders.first { $0.kind == "reveal-hour" }).date) == 3_600)
        #expect(reminders.allSatisfy { $0.identifier(for: summary).hasSuffix(".v7") })
        #expect(Set(reminders.map { $0.identifier(for: summary) }).count == reminders.count)
    }

    @Test func automaticWidgetChoosesActionableThenRetainsLatestRecap() {
        MosaicEventCache.preferredWidgetChallengeID = nil
        defer { MosaicEventCache.preferredWidgetChallengeID = nil }
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let soon = makeSummary(start: now.addingTimeInterval(600), reveal: now.addingTimeInterval(3_600))
        var oldRecap = makeSummary(start: now.addingTimeInterval(-20_000), reveal: now.addingTimeInterval(-10_000))
        oldRecap.serverStatus = "revealed"
        oldRecap.revealedAt = now.addingTimeInterval(-10_000)
        oldRecap.recapAvailability = .ready
        var latestRecap = makeSummary(start: now.addingTimeInterval(-15_000), reveal: now.addingTimeInterval(-5_000))
        latestRecap.serverStatus = "revealed"
        latestRecap.revealedAt = now.addingTimeInterval(-5_000)
        latestRecap.recapAvailability = .ready

        #expect(MosaicEventCache.automaticSummary(from: [latestRecap, soon, oldRecap], at: now)?.id == soon.id)
        #expect(MosaicEventCache.automaticSummary(from: [oldRecap, latestRecap], at: now)?.id == latestRecap.id)
        MosaicEventCache.preferredWidgetChallengeID = oldRecap.id
        #expect(MosaicEventCache.automaticSummary(from: [soon, oldRecap], at: now)?.id == oldRecap.id)
    }

    @Test func deepLinksCoverDetailRevealMissionAndRecap() {
        let id = UUID()
        #expect(EventRouteParser.parse(URL(string: "mosaic://challenge/\(id)")!) == .challenge(id))
        #expect(EventRouteParser.parse(URL(string: "mosaic://reveal/\(id)")!) == .reveal(id))
        #expect(EventRouteParser.parse(URL(string: "mosaic://missions/\(id)")!) == .missions(id))
        #expect(EventRouteParser.parse(URL(string: "mosaic://recap/\(id)")!) == .recap(id))
    }

    @Test func cachedSummaryWithoutThemeMigratesToFallback() throws {
        struct LegacySummary: Encodable {
            let id: UUID; let name: String; let groupName: String; let purpose: String
            let startAt: Date; let revealAt: Date; let revealedAt: Date?
            let serverStatus: String; let scheduleRevision: Int; let contributionCount: Int; let goal: Int
            let recapAvailability: RecapAvailability; let recapThumbnailFilename: String?
        }
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let legacy = LegacySummary(
            id: UUID(), name: "Legacy", groupName: "Neighbors", purpose: "Together",
            startAt: now, revealAt: now.addingTimeInterval(3_600), revealedAt: nil,
            serverStatus: "active", scheduleRevision: 1, contributionCount: 2, goal: 10,
            recapAvailability: .unavailable, recapThumbnailFilename: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ChallengeSummary.self, from: encoder.encode(legacy))
        #expect(decoded.theme == .fallback)
    }

    private func makeSummary(
        start: Date,
        reveal: Date,
        revision: Int = 1
    ) -> ChallengeSummary {
        ChallengeSummary(
            id: UUID(), name: "A Kinder Block", groupName: "Neighbors", purpose: "Together",
            startAt: start, revealAt: reveal, revealedAt: nil, serverStatus: "active",
            scheduleRevision: revision, contributionCount: 4, goal: 10,
            recapAvailability: .unavailable, recapThumbnailFilename: nil
        )
    }
}
