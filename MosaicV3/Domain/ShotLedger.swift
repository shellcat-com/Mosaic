import Foundation

struct ShotLedger: Equatable, Sendable {
    let limit: Int
    private(set) var keptPhotoIDs: Set<UUID>

    init(limit: Int, keptPhotoIDs: Set<UUID> = []) {
        precondition(MosaicDraft.supportedShotLimits.contains(limit))
        self.limit = limit
        self.keptPhotoIDs = keptPhotoIDs
    }

    var used: Int { keptPhotoIDs.count }
    var remaining: Int { max(0, limit - used) }
    var canKeep: Bool { remaining > 0 }

    mutating func keep(_ id: UUID) -> Bool {
        guard canKeep || keptPhotoIDs.contains(id) else { return false }
        keptPhotoIDs.insert(id)
        return true
    }

    mutating func delete(_ id: UUID, beforeReveal: Bool) {
        guard beforeReveal else { return }
        keptPhotoIDs.remove(id)
    }
}
