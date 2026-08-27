import Foundation
import Observation

@MainActor @Observable
final class PlacementCeremonyModel {
    enum Phase: Int, Comparable, Sendable {
        case glaze
        case lift
        case travel
        case settle
        case completed

        static func < (lhs: Phase, rhs: Phase) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private(set) var phase = Phase.glaze
    private var playbackTask: Task<Void, Never>?

    func play(reduceMotion: Bool) {
        guard playbackTask == nil, phase != .completed else { return }
        if reduceMotion {
            phase = .completed
            return
        }
        playbackTask = Task { [weak self] in
            guard let self else { return }
            await advance(to: .lift, after: .milliseconds(420))
            await advance(to: .travel, after: .milliseconds(520))
            await advance(to: .settle, after: .milliseconds(680))
            await advance(to: .completed, after: .milliseconds(420))
            playbackTask = nil
        }
    }

    func skip() {
        playbackTask?.cancel()
        playbackTask = nil
        phase = .completed
    }

    private func advance(to next: Phase, after delay: Duration) async {
        try? await Task.sleep(for: delay)
        guard !Task.isCancelled else { return }
        phase = next
    }
}

@MainActor @Observable
final class RevealPlaybackStore {
    enum Phase: Int, Sendable {
        case idle
        case kilnNight
        case contributed
        case completing
        case attribution
        case completed
    }

    private(set) var eventID: UUID?
    private(set) var phase = Phase.idle
    private(set) var uncoveredPositions = Set<Int>()
    private var playbackTask: Task<Void, Never>?
    private var seenKey: String?

    var isComplete: Bool { phase == .completed }
    var isPlaying: Bool { !isComplete && phase != .idle }

    func prepare(event: MosaicEvent, accountID: UUID?, reduceMotion: Bool) {
        guard eventID != event.id else {
            if phase == .idle { start(event: event, reduceMotion: reduceMotion) }
            return
        }
        playbackTask?.cancel()
        eventID = event.id
        seenKey = Self.seenKey(accountID: accountID, eventID: event.id)
        uncoveredPositions = []
        phase = .idle
        if seenKey.map({ UserDefaults.standard.bool(forKey: $0) }) == true {
            complete(event: event, persist: false)
        } else {
            start(event: event, reduceMotion: reduceMotion)
        }
    }

    func replay(event: MosaicEvent, reduceMotion: Bool) {
        playbackTask?.cancel()
        uncoveredPositions = []
        phase = .idle
        start(event: event, reduceMotion: reduceMotion)
    }

    func skip(event: MosaicEvent) {
        playbackTask?.cancel()
        playbackTask = nil
        complete(event: event, persist: true)
    }

    private func start(event: MosaicEvent, reduceMotion: Bool) {
        guard playbackTask == nil, phase == .idle else { return }
        if reduceMotion {
            playbackTask = Task { [weak self] in
                guard let self else { return }
                phase = .kilnNight
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                phase = .attribution
                uncoveredPositions = Set(0..<event.goal)
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                complete(event: event, persist: true)
                playbackTask = nil
            }
            return
        }

        playbackTask = Task { [weak self] in
            guard let self else { return }
            phase = .kilnNight
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }

            phase = .contributed
            let contributed = event.contributions.map(\.tilePosition)
            await reveal(contributed, totalMilliseconds: 3_000)
            guard !Task.isCancelled else { return }

            phase = .completing
            let contributedSet = Set(contributed)
            let remaining = (0..<event.goal).filter { !contributedSet.contains($0) }
            await reveal(remaining, totalMilliseconds: 1_900)
            guard !Task.isCancelled else { return }

            phase = .attribution
            try? await Task.sleep(for: .milliseconds(1_100))
            guard !Task.isCancelled else { return }
            complete(event: event, persist: true)
            playbackTask = nil
        }
    }

    private func reveal(_ positions: [Int], totalMilliseconds: Int) async {
        guard !positions.isEmpty else { return }
        let batchSize = max(1, Int(ceil(Double(positions.count) / 12.0)))
        let batches = positions.chunked(into: batchSize)
        let delay = max(20, totalMilliseconds / max(1, batches.count))
        for batch in batches {
            guard !Task.isCancelled else { return }
            uncoveredPositions.formUnion(batch)
            try? await Task.sleep(for: .milliseconds(delay))
        }
    }

    private func complete(event: MosaicEvent, persist: Bool) {
        uncoveredPositions = Set(0..<event.goal)
        phase = .completed
        if persist, let seenKey { UserDefaults.standard.set(true, forKey: seenKey) }
    }

    private static func seenKey(accountID: UUID?, eventID: UUID) -> String {
        "mosaic.reveal.seen.\(accountID?.uuidString.lowercased() ?? "local").\(eventID.uuidString.lowercased())"
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
