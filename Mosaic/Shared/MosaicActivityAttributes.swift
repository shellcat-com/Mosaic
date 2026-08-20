import ActivityKit
import Foundation

struct MosaicActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var contributionCount: Int
        var goal: Int
        var revealAt: Date
        var phase: ChallengePhase
        var recapReady: Bool
    }

    let challengeID: UUID
    let challengeName: String
}
