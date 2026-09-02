import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case groups = "Groups"
    case camera = "Camera"
    case profile = "You"

    var icon: MosaicIcon {
        switch self {
        case .groups: .mosaic
        case .camera: .memory
        case .profile: .profile
        }
    }
}

enum MosaicCover: Identifiable, Equatable {
    case missions(UUID?)
    case memory(UUID?)
    case reveal(UUID?)
    case recap(UUID?)

    var id: String {
        switch self {
        case .missions(let id): "missions-\(id?.uuidString ?? "current")"
        case .memory(let id): "memory-\(id?.uuidString ?? "current")"
        case .reveal(let id): "reveal-\(id?.uuidString ?? "current")"
        case .recap(let id): "recap-\(id?.uuidString ?? "current")"
        }
    }
}

enum MosaicSheet: Identifiable {
    case event(ChallengeSummary)
    case memories
    case organizer(returnToChallengeID: UUID?)

    var id: String {
        switch self {
        case .event(let summary): "event-\(summary.id.uuidString)"
        case .memories: "memories"
        case .organizer(let challengeID): "organizer-\(challengeID?.uuidString ?? "none")"
        }
    }
}

@MainActor
@Observable
final class MosaicRouter {
    var selection: AppTab = .groups
    var cover: MosaicCover?
    var sheet: MosaicSheet?
    private(set) var navigationGeneration = 0

    func select(_ tab: AppTab) {
        selection = tab
    }

    func showEvent(_ summary: ChallengeSummary) {
        sheet = .event(summary)
    }

    func showMemories() {
        sheet = .memories
    }

    func showOrganizer(returnTo challengeID: UUID?) {
        sheet = .organizer(returnToChallengeID: challengeID)
    }

    func showMissions(for challengeID: UUID? = nil) {
        present(.missions(challengeID))
    }

    func showMemoryComposer(for challengeID: UUID? = nil) {
        present(.memory(challengeID))
    }

    func showReveal(for challengeID: UUID? = nil) {
        present(.reveal(challengeID))
    }

    func showRecap(for challengeID: UUID? = nil) {
        present(.recap(challengeID))
    }

    func dismissCover() {
        cover = nil
    }

    /// Ends a multi-screen flow at a known app destination and clears any
    /// hidden navigation history that could send someone back into the flow.
    func finishFlow(at destination: AppTab) {
        selection = destination
        sheet = nil
        cover = nil
        navigationGeneration += 1
    }

    private func present(_ destination: MosaicCover) {
        sheet = nil
        cover = destination
    }
}
