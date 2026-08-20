@preconcurrency import ActivityKit
import Foundation

enum LiveFollowResult: Equatable, Sendable {
    case unavailable
    case scheduled
    case started
}

@MainActor
final class MosaicLiveActivityManager {
    static let shared = MosaicLiveActivityManager()
    private var tokenTasks: [UUID: Task<Void, Never>] = [:]

    func follow(
        summary: ChallengeSummary,
        tokenHandler: (@MainActor (String, UUID, String) async -> Void)? = nil
    ) async throws -> LiveFollowResult {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return .unavailable }
        if summary.revealAt.timeIntervalSinceNow > 30 * 60 {
            if let tokenHandler {
                if let token = Activity<MosaicActivityAttributes>.pushToStartToken {
                    await tokenHandler(token.hexString, summary.id, "push-to-start:\(summary.id.uuidString.lowercased())")
                }
                tokenTasks[summary.id]?.cancel()
                tokenTasks[summary.id] = Task {
                    for await token in Activity<MosaicActivityAttributes>.pushToStartTokenUpdates {
                        guard !Task.isCancelled else { return }
                        await tokenHandler(
                            token.hexString,
                            summary.id,
                            "push-to-start:\(summary.id.uuidString.lowercased())"
                        )
                    }
                }
            }
            return .scheduled
        }

        if let existing = Activity<MosaicActivityAttributes>.activities.first(where: {
            $0.attributes.challengeID == summary.id
        }) {
            await update(existing, with: summary)
            return .started
        }

        let attributes = MosaicActivityAttributes(
            challengeID: summary.id,
            challengeName: summary.name
        )
        let state = MosaicActivityAttributes.ContentState(
            contributionCount: summary.contributionCount,
            goal: summary.goal,
            revealAt: summary.revealAt,
            phase: summary.phase(),
            recapReady: summary.recapAvailability == .ready
        )
        let content = ActivityContent(
            state: state,
            staleDate: summary.revealAt.addingTimeInterval(30 * 60)
        )
        let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)

        if let tokenHandler {
            tokenTasks[summary.id]?.cancel()
            tokenTasks[summary.id] = Task {
                for await token in activity.pushTokenUpdates {
                    guard !Task.isCancelled else { return }
                    await tokenHandler(token.hexString, summary.id, activity.id)
                }
            }
        }
        return .started
    }

    func updateActivities(using summaries: [ChallengeSummary]) async {
        for activity in Activity<MosaicActivityAttributes>.activities {
            guard let summary = summaries.first(where: { $0.id == activity.attributes.challengeID }) else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }
            if summary.phase() == .completed {
                let state = contentState(for: summary)
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .after(.now.addingTimeInterval(15 * 60))
                )
            } else {
                await update(activity, with: summary)
            }
        }
    }

    func stop(challengeID: UUID) async {
        tokenTasks[challengeID]?.cancel()
        tokenTasks[challengeID] = nil
        for activity in Activity<MosaicActivityAttributes>.activities
        where activity.attributes.challengeID == challengeID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func update(_ activity: Activity<MosaicActivityAttributes>, with summary: ChallengeSummary) async {
        await activity.update(ActivityContent(
            state: contentState(for: summary),
            staleDate: summary.revealAt.addingTimeInterval(30 * 60)
        ))
    }

    private func contentState(for summary: ChallengeSummary) -> MosaicActivityAttributes.ContentState {
        MosaicActivityAttributes.ContentState(
            contributionCount: summary.contributionCount,
            goal: summary.goal,
            revealAt: summary.revealAt,
            phase: summary.phase(),
            recapReady: summary.recapAvailability == .ready
        )
    }
}

private extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
