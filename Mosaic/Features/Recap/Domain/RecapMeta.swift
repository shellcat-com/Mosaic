import Foundation

struct RecapOrganizerUnit: Codable, Hashable, Sendable, Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

struct RecapImpactReceipt: Codable, Hashable, Sendable {
    let acceptedActions: Int
    let participantCount: Int
    let missionTotals: [RecapMissionCategory: Int]
    let passTheTileJoins: Int
    let organizerUnits: [RecapOrganizerUnit]
    let version: Int
}

struct RecapMeta: Codable, Hashable, Sendable {
    let challengeID: UUID
    let challengeName: String
    let groupName: String
    let startDate: Date
    let endDate: Date
    let goal: Int
    let revealed: Bool
    let impact: RecapImpactReceipt
    let mosaicVersion: Int
    let localeIdentifier: String
    let timeZoneIdentifier: String
    let theme: ThemeSelection

    init(
        challengeID: UUID,
        challengeName: String,
        groupName: String,
        startDate: Date,
        endDate: Date,
        goal: Int,
        revealed: Bool,
        impact: RecapImpactReceipt,
        mosaicVersion: Int,
        localeIdentifier: String,
        timeZoneIdentifier: String,
        theme: ThemeSelection = .fallback
    ) {
        self.challengeID = challengeID
        self.challengeName = challengeName
        self.groupName = groupName
        self.startDate = startDate
        self.endDate = endDate
        self.goal = goal
        self.revealed = revealed
        self.impact = impact
        self.mosaicVersion = mosaicVersion
        self.localeIdentifier = localeIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
        self.theme = theme
    }

    private enum CodingKeys: String, CodingKey {
        case challengeID, challengeName, groupName, startDate, endDate, goal, revealed, impact
        case mosaicVersion, localeIdentifier, timeZoneIdentifier, theme
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        challengeID = try values.decode(UUID.self, forKey: .challengeID)
        challengeName = try values.decode(String.self, forKey: .challengeName)
        groupName = try values.decode(String.self, forKey: .groupName)
        startDate = try values.decode(Date.self, forKey: .startDate)
        endDate = try values.decode(Date.self, forKey: .endDate)
        goal = try values.decode(Int.self, forKey: .goal)
        revealed = try values.decode(Bool.self, forKey: .revealed)
        impact = try values.decode(RecapImpactReceipt.self, forKey: .impact)
        mosaicVersion = try values.decode(Int.self, forKey: .mosaicVersion)
        localeIdentifier = try values.decode(String.self, forKey: .localeIdentifier)
        timeZoneIdentifier = try values.decode(String.self, forKey: .timeZoneIdentifier)
        theme = try values.decodeIfPresent(ThemeSelection.self, forKey: .theme) ?? .fallback
    }
}
