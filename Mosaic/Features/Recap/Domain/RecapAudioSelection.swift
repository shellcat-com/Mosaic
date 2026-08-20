import Foundation

struct RecapAudioSelection: Codable, Hashable, Sendable {
    let trackID: String?
    var trimOffset: TimeInterval

    static let silent = RecapAudioSelection(trackID: nil, trimOffset: 0)
}
