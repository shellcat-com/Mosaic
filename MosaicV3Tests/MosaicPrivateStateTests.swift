import Foundation
import Testing
@testable import Mosaic

@MainActor
struct MosaicPrivateStateTests {
    @Test
    func signOutClearsPrivateStoresAndNavigation() async {
        let model = MosaicShowcaseFixtures.makeModel()
        await model.library.refresh()
        await model.detail.load(id: MosaicShowcaseFixtures.activeID)
        let event = model.detail.event
        model.camera.select(event?.summary)
        model.router.mosaicsPath = [.event(MosaicShowcaseFixtures.activeID)]
        model.router.youPath = [.blockedUsers]
        var creationDraft = MosaicDraft()
        creationDraft.name = "Private draft"
        model.creativeDrafts.saveCreation(draft: creationDraft, step: 2, selectedPresetID: "community")
        var recapSelection = PhotoRecapSelection()
        recapSelection.toggle(UUID())
        model.creativeDrafts.saveRecap(
            PhotoRecapProject(mosaicID: MosaicShowcaseFixtures.activeID, selection: recapSelection),
            stage: "Style"
        )

        #expect(!model.library.mosaics.isEmpty)
        #expect(model.detail.event != nil)
        #expect(model.camera.selectedEvent != nil)
        #expect(model.creativeDrafts.creation != nil)
        #expect(model.creativeDrafts.recapProject(for: MosaicShowcaseFixtures.activeID) != nil)

        await model.signOut()

        #expect(model.session.phase == .signedOut)
        #expect(model.library.mosaics.isEmpty)
        #expect(model.detail.event == nil)
        #expect(model.camera.selectedEvent == nil)
        #expect(model.router.mosaicsPath.isEmpty)
        #expect(model.router.youPath.isEmpty)
        #expect(model.creativeDrafts.creation == nil)
        #expect(model.creativeDrafts.recapProject(for: MosaicShowcaseFixtures.activeID) == nil)
    }

    @Test
    func premiumCreateRetryReusesRequestIDUntilSuccess() async {
        let api = PremiumCreateRetryAPI()
        let store = MosaicLibraryStore(api: api)
        var draft = MosaicDraft()
        draft.goal = 36
        let billing = BillingSnapshot(
            plusActive: false,
            subscriptionState: .none,
            productID: nil,
            expiresAt: nil,
            willRenew: false,
            passBalance: 1,
            synchronizedAt: nil
        )

        await #expect(throws: MosaicAPIError.message("Offline")) {
            try await store.create(draft, billingSnapshot: billing)
        }
        await #expect(throws: MosaicAPIError.message("Offline")) {
            try await store.create(draft, billingSnapshot: billing)
        }

        let requestIDs = await api.requestIDs
        #expect(requestIDs.count == 2)
        #expect(requestIDs.first == requestIDs.last)
    }

    @Test
    func premiumCreateUsesANewRequestIDAfterTheDraftChanges() async {
        let api = PremiumCreateRetryAPI()
        let store = MosaicLibraryStore(api: api)
        var draft = MosaicDraft()
        draft.goal = 36
        let billing = BillingSnapshot(
            plusActive: false,
            subscriptionState: .none,
            productID: nil,
            expiresAt: nil,
            willRenew: false,
            passBalance: 1,
            synchronizedAt: nil
        )

        await #expect(throws: MosaicAPIError.message("Offline")) {
            try await store.create(draft, billingSnapshot: billing)
        }
        draft.name = "A different Mosaic"
        await #expect(throws: MosaicAPIError.message("Offline")) {
            try await store.create(draft, billingSnapshot: billing)
        }

        let requestIDs = await api.requestIDs
        #expect(requestIDs.count == 2)
        #expect(requestIDs.first != requestIDs.last)
    }

    @Test
    func clearingPrivateStateInvalidatesAnInFlightLibraryRefresh() async {
        let api = PremiumCreateRetryAPI()
        let store = MosaicLibraryStore(api: api)
        let refresh = Task { await store.refresh() }
        while !(await api.hasPendingListRequest()) { await Task.yield() }

        store.clearPrivateState()
        await api.finishList(with: MosaicShowcaseFixtures.makeEvents().map(\.summary))
        await refresh.value

        #expect(store.mosaics.isEmpty)
        #expect(!store.isLoading)
        #expect(store.message == nil)
    }

    @Test
    func clearingPrivateStateInvalidatesAnInFlightDetailLoad() async {
        let api = PremiumCreateRetryAPI()
        let store = MosaicDetailStore(api: api)
        let event = MosaicShowcaseFixtures.makeEvents()[0]
        let load = Task { await store.load(id: event.id) }
        while !(await api.hasPendingLoadRequest(for: event.id)) { await Task.yield() }

        await store.clearPrivateState()
        await api.finishLoad(with: event)
        await load.value

        #expect(store.event == nil)
        #expect(!store.isLoading)
        #expect(store.message == nil)
    }

    @Test
    func newestDetailLoadWinsWhenResponsesFinishOutOfOrder() async {
        let api = PremiumCreateRetryAPI()
        let store = MosaicDetailStore(api: api)
        let events = MosaicShowcaseFixtures.makeEvents()
        let first = events[0]
        let second = events[1]
        let firstLoad = Task { await store.load(id: first.id) }
        while !(await api.hasPendingLoadRequest(for: first.id)) { await Task.yield() }
        let secondLoad = Task { await store.load(id: second.id) }
        while !(await api.hasPendingLoadRequest(for: second.id)) { await Task.yield() }

        await api.finishLoad(with: second)
        await secondLoad.value
        await api.finishLoad(with: first)
        await firstLoad.value

        #expect(store.event?.id == second.id)
        #expect(!store.isLoading)
        #expect(store.message == nil)
    }
}

private actor PremiumCreateRetryAPI: MosaicAPI {
    private(set) var requestIDs: [UUID] = []
    private var listContinuation: CheckedContinuation<[MosaicSummary], any Error>?
    private var loadContinuations: [UUID: CheckedContinuation<MosaicEvent, any Error>] = [:]

    func listMosaics() async throws -> [MosaicSummary] {
        try await withCheckedThrowingContinuation { listContinuation = $0 }
    }
    func hasPendingListRequest() -> Bool { listContinuation != nil }
    func finishList(with summaries: [MosaicSummary]) {
        listContinuation?.resume(returning: summaries)
        listContinuation = nil
    }
    func createMosaic(_ draft: MosaicDraft) async throws -> MosaicEvent { throw MosaicAPIError.invalidResponse }
    func createPremiumMosaic(_ draft: MosaicDraft, requestID: UUID) async throws -> MosaicEvent {
        requestIDs.append(requestID)
        throw MosaicAPIError.message("Offline")
    }
    func billingSnapshot() async throws -> BillingSnapshot { .free }
    func refreshBilling() async throws -> BillingSnapshot { .free }
    func resolveInvitation(_ code: String) async throws -> MosaicInvitationPreview { throw MosaicAPIError.invalidResponse }
    func joinMosaic(_ code: String) async throws -> MosaicEvent { throw MosaicAPIError.invalidResponse }
    func loadMosaic(_ id: UUID) async throws -> MosaicEvent {
        try await withCheckedThrowingContinuation { loadContinuations[id] = $0 }
    }
    func hasPendingLoadRequest(for id: UUID) -> Bool { loadContinuations[id] != nil }
    func finishLoad(with event: MosaicEvent) {
        loadContinuations.removeValue(forKey: event.id)?.resume(returning: event)
    }
    func updateMosaic(_ id: UUID, name: String, description: String) async throws -> MosaicEvent { throw MosaicAPIError.invalidResponse }
    func deleteMosaic(_ id: UUID) async throws { throw MosaicAPIError.invalidResponse }
    func completeActivity(mosaicID: UUID, activityID: UUID, note: String?) async throws -> KindnessContribution { throw MosaicAPIError.invalidResponse }
    func updateContribution(_ id: UUID, note: String?) async throws -> KindnessContribution { throw MosaicAPIError.invalidResponse }
    func withdrawContribution(_ id: UUID) async throws { throw MosaicAPIError.invalidResponse }
    func preparePhoto(mosaicID: UUID, photoID: UUID, byteCount: Int, pixelWidth: Int, pixelHeight: Int) async throws -> PreparedPhotoUpload { throw MosaicAPIError.invalidResponse }
    func uploadPhoto(_ upload: PreparedPhotoUpload, jpeg: Data) async throws { throw MosaicAPIError.invalidResponse }
    func finalizePhoto(_ photoID: UUID) async throws -> EventPhoto { throw MosaicAPIError.invalidResponse }
    func deletePhoto(_ photoID: UUID) async throws { throw MosaicAPIError.invalidResponse }
    func reportPhoto(_ photoID: UUID, reason: String) async throws { throw MosaicAPIError.invalidResponse }
    func blockUser(_ userID: UUID) async throws { throw MosaicAPIError.invalidResponse }
    func unblockUser(_ userID: UUID) async throws { throw MosaicAPIError.invalidResponse }
    func blockedUsers() async throws -> [BlockedUser] { [] }
    func releaseArtwork(_ mosaicID: UUID) async throws -> ArtworkRevealMaterial? { nil }
}
