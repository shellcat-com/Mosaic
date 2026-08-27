import Foundation
import Observation

enum PaywallLoadState: Equatable { case idle, loading, loaded, failed(String) }
enum BillingActionState: Equatable { case idle, purchasing, pending, synchronizing, success, failed(String) }
enum MosaicPaywallContext: String, Sendable { case creationChoice, freeCreationLimit, account }

enum MosaicPriceMath {
    static func annualSavingsPercent(annual: MonetizationPackage?, monthly: MonetizationPackage?) -> Int? {
        guard let annual, let monthly, annual.kind == .annual, monthly.kind == .monthly,
              annual.currencyCode == monthly.currencyCode, annual.price > 0, monthly.price > 0 else { return nil }
        let comparison = monthly.price * 12
        guard comparison > annual.price else { return nil }
        return NSDecimalNumber(decimal: ((comparison - annual.price) / comparison) * 100).intValue
    }
}

@MainActor @Observable
final class BillingStore {
    private let purchases: any RevenueCatPurchasing
    private let api: any MosaicAPI
    private(set) var snapshot = BillingSnapshot.free
    private(set) var packages: [MonetizationPackage] = []
    private(set) var loadState = PaywallLoadState.idle
    private(set) var actionState = BillingActionState.idle
    private(set) var configuredUserID: String?
    var selectedProductID: String?
    var isShowingPaywall = false
    var paywallContext = MosaicPaywallContext.account

    init(purchases: any RevenueCatPurchasing, api: any MosaicAPI) { self.purchases = purchases; self.api = api }

    var annualSavingsPercent: Int? {
        MosaicPriceMath.annualSavingsPercent(annual: packages.first { $0.kind == .annual }, monthly: packages.first { $0.kind == .monthly })
    }

    func configure(userID: UUID) async {
        let normalized = userID.uuidString.lowercased()
        guard configuredUserID != normalized else { return }
        loadState = .loading
        do {
            try await purchases.configure(appUserID: normalized)
            configuredUserID = normalized
            snapshot = (try? await api.billingSnapshot()) ?? .free
            packages = try await purchases.loadOfferings()
            selectedProductID = packages.first { $0.kind == .annual }?.productIdentifier
            loadState = .loaded
        } catch { loadState = .failed(error.localizedDescription) }
    }

    func present(_ context: MosaicPaywallContext) {
        paywallContext = context; actionState = .idle; isShowingPaywall = true
        if packages.isEmpty { Task { await reloadOfferings() } }
    }

    func reloadOfferings() async {
        loadState = .loading
        do {
            packages = try await purchases.loadOfferings()
            selectedProductID = selectedProductID ?? packages.first { $0.kind == .annual }?.productIdentifier
            loadState = .loaded
        } catch { loadState = .failed(error.localizedDescription) }
    }

    func purchaseSelected() async {
        guard let selectedProductID else { return }
        actionState = .purchasing
        do {
            switch try await purchases.purchase(productIdentifier: selectedProductID) {
            case .cancelled: actionState = .idle
            case .pending: actionState = .pending
            case .purchased:
                actionState = .synchronizing
                try await reconcileServer()
                actionState = .success
            }
        } catch { actionState = .failed(error.localizedDescription) }
    }

    func restore() async {
        actionState = .synchronizing
        do { try await purchases.restore(); try await reconcileServer(); actionState = .success }
        catch { actionState = .failed(error.localizedDescription) }
    }

    func refreshServer() async {
        do { try await reconcileServer() }
        catch { actionState = .failed(error.localizedDescription) }
    }

    func logOut() async {
        try? await purchases.logOut()
        configuredUserID = nil; snapshot = .free; packages = []; selectedProductID = nil
        loadState = .idle; actionState = .idle; isShowingPaywall = false
    }

    func setShowcase(
        snapshot: BillingSnapshot,
        packages: [MonetizationPackage] = MockRevenueCatPurchasing.fixturePackages,
        loadState: PaywallLoadState = .loaded,
        actionState: BillingActionState = .idle
    ) {
        self.snapshot = snapshot; self.packages = packages
        selectedProductID = packages.first { $0.kind == .annual }?.productIdentifier
        self.loadState = loadState; self.actionState = actionState
    }

    private func reconcileServer() async throws {
        try await purchases.refreshCustomerInfo()
        snapshot = try await api.refreshBilling()
    }
}
