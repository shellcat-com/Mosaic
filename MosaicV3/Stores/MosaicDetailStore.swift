import Foundation
import Observation

@MainActor @Observable
final class MosaicDetailStore {
    private let api: any MosaicAPI
    private let artworkCache: ArtworkRevealCache
    private(set) var event: MosaicEvent?
    private(set) var isLoading = false
    private(set) var placedTilePosition: Int?
    private(set) var revealedArtworkURL: URL?
    var message: String?
    var selectedOutcome = CompletedOutcome.artwork

    enum CompletedOutcome: String, CaseIterable, Identifiable {
        case artwork = "Artwork"
        case kindness = "Kindness"
        case photos = "Photos"
        var id: String { rawValue }
    }

    init(api: any MosaicAPI, artworkCache: ArtworkRevealCache = ArtworkRevealCache()) {
        self.api = api
        self.artworkCache = artworkCache
    }

    func load(id: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await api.loadMosaic(id)
            event = loaded
            if loaded.phase == .revealed {
                await loadReleasedArtwork(for: loaded.id)
            } else {
                revealedArtworkURL = nil
            }
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    private func loadReleasedArtwork(for mosaicID: UUID) async {
        do {
            guard let material = try await api.releaseArtwork(mosaicID) else { return }
            revealedArtworkURL = try await artworkCache.decrypt(material)
        } catch {
            // Bundled reviewed artwork remains a safe offline fallback.
            revealedArtworkURL = nil
        }
    }

    func complete(_ activity: KindnessActivity, note: String?) async throws {
        guard let event else { return }
        let contribution = try await api.completeActivity(mosaicID: event.id, activityID: activity.id, note: note)
        self.event?.contributions.append(contribution)
        self.event?.contributionCount += 1
        self.event?.occupiedTilePositions.append(contribution.tilePosition)
        if let index = self.event?.activities.firstIndex(where: { $0.id == activity.id }) {
            self.event?.activities[index].participantCompleted = true
        }
        placedTilePosition = contribution.tilePosition
    }

    func clearPlacementCeremony() {
        placedTilePosition = nil
    }

    func clearPrivateState() async {
        event = nil
        isLoading = false
        placedTilePosition = nil
        revealedArtworkURL = nil
        message = nil
        selectedOutcome = .artwork
        try? await artworkCache.clearAll()
    }

    func updateNote(contributionID: UUID, note: String?) async throws {
        let updated = try await api.updateContribution(contributionID, note: note)
        if let index = event?.contributions.firstIndex(where: { $0.id == contributionID }) {
            event?.contributions[index] = updated
        }
    }

    func undo(contributionID: UUID) async throws {
        try await api.withdrawContribution(contributionID)
        guard let removed = event?.contributions.first(where: { $0.id == contributionID }) else { return }
        event?.contributions.removeAll { $0.id == contributionID }
        event?.contributionCount = max(0, (event?.contributionCount ?? 1) - 1)
        event?.occupiedTilePositions.removeAll { $0 == removed.tilePosition }
        if event?.contributions.contains(where: { $0.activityID == removed.activityID && $0.isMine }) == false,
           let index = event?.activities.firstIndex(where: { $0.id == removed.activityID }) {
            event?.activities[index].participantCompleted = false
        }
    }

    func updateMetadata(name: String, description: String) async throws {
        guard let id = event?.id else { return }
        event = try await api.updateMosaic(id, name: name, description: description)
    }

    func deleteEvent() async throws {
        guard let id = event?.id else { return }
        try await api.deleteMosaic(id)
        event = nil
    }

    func deletePhoto(_ id: UUID) async throws {
        try await api.deletePhoto(id)
        event?.photos.removeAll { $0.id == id }
    }

    func reportPhoto(_ id: UUID, reason: String) async throws {
        try await api.reportPhoto(id, reason: reason)
        event?.photos.removeAll { $0.id == id }
    }

    func block(_ participantID: UUID) async throws {
        try await api.blockUser(participantID)
        event?.photos.removeAll { $0.photographerID == participantID }
    }
}
