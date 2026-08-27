import Foundation

struct KindnessActivityDraft: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var purpose: String

    init(id: UUID = UUID(), title: String = "", purpose: String = "") {
        self.id = id
        self.title = title
        self.purpose = purpose
    }
}

struct KindnessActivity: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let mosaicID: UUID
    var title: String
    var purpose: String
    var sortOrder: Int
    var participantCompleted: Bool
}

struct KindnessContribution: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let mosaicID: UUID
    let activityID: UUID
    let participantID: UUID
    let contributorDisplayName: String?
    let tilePosition: Int
    var note: String?
    let createdAt: Date
    var updatedAt: Date
    let isMine: Bool
}
