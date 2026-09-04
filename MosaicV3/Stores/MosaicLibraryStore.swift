import Foundation
import Observation

@MainActor @Observable
final class MosaicLibraryStore {
    private let api: any MosaicAPI
    @ObservationIgnored private var stateGeneration: UInt = 0
    @ObservationIgnored private var pendingPremiumCreate: (draft: MosaicDraft, requestID: UUID)?
    private(set) var mosaics: [MosaicSummary] = []
    private(set) var isLoading = false
    var message: String?

    init(api: any MosaicAPI) {
        self.api = api
    }

    var active: [MosaicSummary] { mosaics.filter { $0.phase != .revealed } }
    var completed: [MosaicSummary] { mosaics.filter { $0.phase == .revealed } }

    func refresh() async {
        let generation = stateGeneration
        isLoading = true
        defer {
            if generation == stateGeneration { isLoading = false }
        }
        do {
            let loaded = try await api.listMosaics()
            guard generation == stateGeneration else { return }
            mosaics = loaded
            message = nil
        } catch {
            guard generation == stateGeneration else { return }
            message = error.localizedDescription
        }
    }

    func create(_ draft: MosaicDraft, billingSnapshot: BillingSnapshot = .free) async throws -> MosaicEvent {
        let generation = stateGeneration
        let event: MosaicEvent
        if draft.requiresPremiumAccess && !billingSnapshot.plusActive {
            guard billingSnapshot.passBalance > 0 else { throw MosaicAPIError.premiumRequired }
            let requestID: UUID
            if let pendingPremiumCreate, pendingPremiumCreate.draft == draft {
                requestID = pendingPremiumCreate.requestID
            } else {
                requestID = UUID()
            }
            pendingPremiumCreate = (draft, requestID)
            event = try await api.createPremiumMosaic(draft, requestID: requestID)
            guard generation == stateGeneration else { throw CancellationError() }
            pendingPremiumCreate = nil
        } else {
            pendingPremiumCreate = nil
            event = try await api.createMosaic(draft)
            guard generation == stateGeneration else { throw CancellationError() }
        }
        replace(event.summary)
        return event
    }

    func join(code: String) async throws -> MosaicEvent {
        let generation = stateGeneration
        let event = try await api.joinMosaic(code)
        guard generation == stateGeneration else { throw CancellationError() }
        replace(event.summary)
        return event
    }

    func resolve(code: String) async throws -> MosaicInvitationPreview {
        try await api.resolveInvitation(code)
    }

    func remove(id: UUID) {
        mosaics.removeAll { $0.id == id }
    }

    func clearPrivateState() {
        stateGeneration &+= 1
        mosaics = []
        isLoading = false
        message = nil
        pendingPremiumCreate = nil
    }

    func replace(_ summary: MosaicSummary) {
        mosaics.removeAll { $0.id == summary.id }
        mosaics.append(summary)
        mosaics.sort { $0.revealAt < $1.revealAt }
    }
}
