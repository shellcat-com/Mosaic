@preconcurrency import RevenueCat
import Foundation

struct RevenueCatConfiguration: Sendable, Equatable {
    let publicSDKKey: String
    let billingEnabled: Bool

    static var current: Self? {
        let environment = ProcessInfo.processInfo.environment
        let key = environment["REVENUECAT_PUBLIC_SDK_KEY"] ?? Bundle.main.object(forInfoDictionaryKey: "RevenueCatPublicSDKKey") as? String
        let rawEnabled = environment["MOSAIC_BILLING_ENABLED"] ?? Bundle.main.object(forInfoDictionaryKey: "MosaicBillingEnabled") as? String
        let enabled = ["YES", "TRUE", "1"].contains(rawEnabled?.uppercased() ?? "")
        guard let key, enabled, !key.isEmpty, !key.contains("$(") else { return nil }
        return Self(publicSDKKey: key, billingEnabled: enabled)
    }

    func validate(isDebugBuild: Bool) throws {
        guard billingEnabled, !publicSDKKey.isEmpty else { throw BillingConfigurationError.missingPublicKey }
        if !isDebugBuild && publicSDKKey.lowercased().hasPrefix("test_") { throw BillingConfigurationError.testKeyInRelease }
    }
}

@MainActor
final class RevenueCatBillingService: RevenueCatPurchasing {
    private let configuration: RevenueCatConfiguration?
    private var configuredUserID: String?
    private var packagesByProductID: [String: Package] = [:]

    init(configuration: RevenueCatConfiguration? = .current) { self.configuration = configuration }

    func configure(appUserID: String) async throws {
        guard let configuration else { throw BillingConfigurationError.missingPublicKey }
        #if DEBUG
        try configuration.validate(isDebugBuild: true)
        Purchases.logLevel = .debug
        #else
        try configuration.validate(isDebugBuild: false)
        #endif
        let normalizedID = appUserID.lowercased()
        if Purchases.isConfigured {
            if Purchases.shared.appUserID != normalizedID { _ = try await Purchases.shared.logIn(normalizedID) }
        } else {
            Purchases.configure(withAPIKey: configuration.publicSDKKey, appUserID: normalizedID)
        }
        configuredUserID = normalizedID
    }

    func loadOfferings() async throws -> [MonetizationPackage] {
        guard configuredUserID != nil else { throw BillingConfigurationError.notConfigured }
        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.all[MosaicBillingCatalog.offeringID] else { throw BillingConfigurationError.offeringUnavailable }
        let mapped = offering.availablePackages.compactMap(map)
        let expected = Set([MosaicBillingCatalog.monthlyProductID, MosaicBillingCatalog.annualProductID, MosaicBillingCatalog.eventPassProductID])
        guard Set(mapped.map(\.productIdentifier)).isSuperset(of: expected) else { throw BillingConfigurationError.offeringUnavailable }
        packagesByProductID = Dictionary(uniqueKeysWithValues: offering.availablePackages.map { ($0.storeProduct.productIdentifier, $0) })
        return mapped.sorted { $0.kind.sortOrder < $1.kind.sortOrder }
    }

    func purchase(productIdentifier: String) async throws -> BillingPurchaseOutcome {
        guard configuredUserID != nil else { throw BillingConfigurationError.notConfigured }
        if packagesByProductID[productIdentifier] == nil { _ = try await loadOfferings() }
        guard let package = packagesByProductID[productIdentifier] else { throw BillingConfigurationError.packageUnavailable(productIdentifier) }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            return result.userCancelled ? .cancelled : .purchased
        } catch {
            if (error as NSError).code == ErrorCode.paymentPendingError.rawValue { return .pending }
            throw error
        }
    }

    func restore() async throws {
        guard configuredUserID != nil else { throw BillingConfigurationError.notConfigured }
        _ = try await Purchases.shared.restorePurchases()
    }
    func refreshCustomerInfo() async throws {
        guard configuredUserID != nil else { throw BillingConfigurationError.notConfigured }
        _ = try await Purchases.shared.customerInfo()
    }
    func logOut() async throws {
        packagesByProductID.removeAll(); configuredUserID = nil
        guard Purchases.isConfigured else { return }
        _ = try await Purchases.shared.logOut()
    }

    private func map(_ package: Package) -> MonetizationPackage? {
        let product = package.storeProduct
        let kind: MonetizationProductKind
        let period: String
        switch product.productIdentifier {
        case MosaicBillingCatalog.annualProductID: kind = .annual; period = product.subscriptionPeriod.map(Self.describe) ?? ""
        case MosaicBillingCatalog.monthlyProductID: kind = .monthly; period = product.subscriptionPeriod.map(Self.describe) ?? ""
        case MosaicBillingCatalog.eventPassProductID: kind = .eventPass; period = "one Mosaic"
        default: return nil
        }
        return MonetizationPackage(
            packageIdentifier: package.identifier, productIdentifier: product.productIdentifier,
            localizedPrice: product.localizedPriceString, price: product.price,
            currencyCode: product.priceFormatter?.currencyCode, period: period,
            introductoryOffer: product.introductoryDiscount.map(Self.describeIntroductoryOffer), kind: kind
        )
    }

    private static func describeIntroductoryOffer(_ discount: StoreProductDiscount) -> String {
        let count = discount.subscriptionPeriod.value * discount.numberOfPeriods
        let unit: String
        switch discount.subscriptionPeriod.unit {
        case .day: unit = count == 1 ? "day" : "days"
        case .week: unit = count == 1 ? "week" : "weeks"
        case .month: unit = count == 1 ? "month" : "months"
        case .year: unit = count == 1 ? "year" : "years"
        @unknown default: return discount.localizedPriceString
        }
        switch discount.paymentMode {
        case .freeTrial: return "Free for \(count) \(unit)"
        case .payAsYouGo, .payUpFront: return "\(discount.localizedPriceString) for \(count) \(unit)"
        @unknown default: return discount.localizedPriceString
        }
    }

    private static func describe(_ period: SubscriptionPeriod) -> String {
        let noun: String
        switch period.unit {
        case .day: noun = period.value == 1 ? "day" : "days"
        case .week: noun = period.value == 1 ? "week" : "weeks"
        case .month: noun = period.value == 1 ? "month" : "months"
        case .year: noun = period.value == 1 ? "year" : "years"
        @unknown default: return ""
        }
        return period.value == 1 ? "per \(noun)" : "every \(period.value) \(noun)"
    }
}

private extension MonetizationProductKind {
    var sortOrder: Int { switch self { case .annual: 0; case .monthly: 1; case .eventPass: 2 } }
}
