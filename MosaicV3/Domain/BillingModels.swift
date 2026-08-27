import Foundation

enum MosaicBillingCatalog {
    static let offeringID = "organizer_plus_v1"
    static let entitlementID = "organizer_plus"
    static let monthlyProductID = "organizer_monthly"
    static let annualProductID = "organizer_annual"
    static let eventPassProductID = "mosaic_event_pass_v2"
    static let passCurrencyCode = "PASS"
}

enum MosaicAccessSource: String, Codable, CaseIterable, Hashable, Sendable {
    case free
    case organizerPlus = "organizer_plus"
    case eventPass = "event_pass"
}

enum BillingSubscriptionState: String, Codable, Hashable, Sendable {
    case none, trialing, active
    case gracePeriod = "grace_period"
    case billingIssue = "billing_issue"
    case cancelled, expired
}

struct BillingSnapshot: Codable, Equatable, Sendable {
    let plusActive: Bool
    let subscriptionState: BillingSubscriptionState
    let productID: String?
    let expiresAt: Date?
    let willRenew: Bool
    let passBalance: Int
    let synchronizedAt: Date?

    static let free = Self(plusActive: false, subscriptionState: .none, productID: nil, expiresAt: nil, willRenew: false, passBalance: 0, synchronizedAt: nil)
    var canStartPremiumMosaic: Bool { plusActive || passBalance > 0 }
    var capabilities: MosaicPremiumCapabilities { canStartPremiumMosaic ? .premium : .free }
}

enum MonetizationProductKind: String, Codable, CaseIterable, Hashable, Sendable {
    case annual, monthly, eventPass
}

struct MonetizationPackage: Identifiable, Equatable, Hashable, Sendable {
    let packageIdentifier: String
    let productIdentifier: String
    let localizedPrice: String
    let price: Decimal
    let currencyCode: String?
    let period: String
    let introductoryOffer: String?
    let kind: MonetizationProductKind
    var id: String { productIdentifier }
}

enum BillingPurchaseOutcome: Equatable, Sendable { case purchased, cancelled, pending }

enum BillingConfigurationError: LocalizedError, Equatable {
    case missingPublicKey, testKeyInRelease, notConfigured, offeringUnavailable
    case packageUnavailable(String)
    case serverConfirmationTimedOut

    var errorDescription: String? {
        switch self {
        case .missingPublicKey: "RevenueCat is not configured for this build."
        case .testKeyInRelease: "A RevenueCat Test Store key cannot be used in a Release build."
        case .notConfigured: "Billing will be ready after Mosaic restores your session."
        case .offeringUnavailable: "The Mosaic offering is temporarily unavailable. Please try again."
        case .packageUnavailable(let id): "The RevenueCat offering does not contain \(id)."
        case .serverConfirmationTimedOut: "The purchase succeeded, but Mosaic is still confirming access. Try Sync purchases in a moment."
        }
    }
}

struct MosaicPremiumCapabilities: Codable, Equatable, Hashable, Sendable {
    let canCreateMultipleActiveMosaics: Bool
    let maximumTileGoal: Int
    let maximumShotLimit: Int
    let availableFilmLooks: [FilmLookID]

    static let free = Self(canCreateMultipleActiveMosaics: false, maximumTileGoal: 25, maximumShotLimit: 12, availableFilmLooks: [.sunwashed])
    static let premium = Self(canCreateMultipleActiveMosaics: true, maximumTileGoal: 100, maximumShotLimit: 36, availableFilmLooks: FilmLookID.allCases)
}

extension MosaicDraft {
    static let freeGoals = [9, 16, 25]
    static let premiumGoals = [36, 49, 64, 81, 100]
    var requiresPremiumAccess: Bool { goal > 25 || shotLimit > 12 || filmLookID != .sunwashed }
}

@MainActor
protocol RevenueCatPurchasing: AnyObject {
    func configure(appUserID: String) async throws
    func loadOfferings() async throws -> [MonetizationPackage]
    func purchase(productIdentifier: String) async throws -> BillingPurchaseOutcome
    func restore() async throws
    func refreshCustomerInfo() async throws
    func logOut() async throws
}

@MainActor
final class MockRevenueCatPurchasing: RevenueCatPurchasing {
    var packages: [MonetizationPackage]
    var purchaseOutcome: BillingPurchaseOutcome
    var error: Error?
    private(set) var configuredUserID: String?

    init(packages: [MonetizationPackage] = MockRevenueCatPurchasing.fixturePackages, purchaseOutcome: BillingPurchaseOutcome = .purchased, error: Error? = nil) {
        self.packages = packages; self.purchaseOutcome = purchaseOutcome; self.error = error
    }

    func configure(appUserID: String) async throws { configuredUserID = appUserID.lowercased() }
    func loadOfferings() async throws -> [MonetizationPackage] { if let error { throw error }; return packages }
    func purchase(productIdentifier: String) async throws -> BillingPurchaseOutcome { if let error { throw error }; return purchaseOutcome }
    func restore() async throws { if let error { throw error } }
    func refreshCustomerInfo() async throws { if let error { throw error } }
    func logOut() async throws { configuredUserID = nil }

    static let fixturePackages = [
        MonetizationPackage(packageIdentifier: "$rc_annual", productIdentifier: MosaicBillingCatalog.annualProductID, localizedPrice: "$39.99", price: 39.99, currencyCode: "USD", period: "per year", introductoryOffer: nil, kind: .annual),
        MonetizationPackage(packageIdentifier: "$rc_monthly", productIdentifier: MosaicBillingCatalog.monthlyProductID, localizedPrice: "$5.99", price: 5.99, currencyCode: "USD", period: "per month", introductoryOffer: nil, kind: .monthly),
        MonetizationPackage(packageIdentifier: "event_pass", productIdentifier: MosaicBillingCatalog.eventPassProductID, localizedPrice: "$8.99", price: 8.99, currencyCode: "USD", period: "one Mosaic", introductoryOffer: nil, kind: .eventPass)
    ]
}
