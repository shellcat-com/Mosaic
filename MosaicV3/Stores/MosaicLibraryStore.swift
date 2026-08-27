import Foundation
import Observation

@MainActor @Observable
final class MosaicLibraryStore {
    private let api: any MosaicAPI
    private(set) var mosaics: [MosaicSummary] = []
    private(set) var isLoading = false
    var message: String?

    init(api: any MosaicAPI) {
        self.api = api
    }

    var active: [MosaicSummary] { mosaics.filter { $0.phase != .revealed } }
    var completed: [MosaicSummary] { mosaics.filter { $0.phase == .revealed } }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            mosaics = try await api.listMosaics()
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    func create(_ draft: MosaicDraft, billingSnapshot: BillingSnapshot = .free) async throws -> MosaicEvent {
        let event: MosaicEvent
        if draft.requiresPremiumAccess && !billingSnapshot.plusActive {
            guard billingSnapshot.passBalance > 0 else { throw MosaicAPIError.premiumRequired }
            event = try await api.createPremiumMosaic(draft, requestID: UUID())
        } else {
            event = try await api.createMosaic(draft)
        }
        replace(event.summary)
        return event
    }

    func join(code: String) async throws -> MosaicEvent {
        let event = try await api.joinMosaic(code)
        replace(event.summary)
        return event
    }

    func resolve(code: String) async throws -> MosaicInvitationPreview {
        try await api.resolveInvitation(code)
    }

    func remove(id: UUID) {
        mosaics.removeAll { $0.id == id }
    }

    func replace(_ summary: MosaicSummary) {
        mosaics.removeAll { $0.id == summary.id }
        mosaics.append(summary)
        mosaics.sort { $0.revealAt < $1.revealAt }
    }
}
