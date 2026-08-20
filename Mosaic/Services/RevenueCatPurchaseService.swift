import Foundation
import RevenueCat
import Supabase

struct RevenueCatConfiguration: Sendable {
    let publicSDKKey: String

    static var current: RevenueCatConfiguration? {
        let environment = ProcessInfo.processInfo.environment
        let value = environment["REVENUECAT_PUBLIC_SDK_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "RevenueCatPublicSDKKey") as? String
        guard let value, !value.isEmpty, !value.contains("$(") else { return nil }
        return RevenueCatConfiguration(publicSDKKey: value)
    }

    func validate() throws {
#if !DEBUG
        if publicSDKKey.lowercased().hasPrefix("test_") {
            throw RevenueCatServiceError.testKeyInRelease
        }
#endif
    }
}

@MainActor
final class RevenueCatPurchaseService: PurchaseServicing {
    private let configuration: RevenueCatConfiguration?
    private let client: SupabaseClient
    private let workspace: WorkspaceServicing
    private var customerID: UUID?

    init(configuration: RevenueCatConfiguration?, client: SupabaseClient, workspace: WorkspaceServicing) {
        self.configuration = configuration
        self.client = client
        self.workspace = workspace
    }

    func configure(customerID: UUID) async throws {
        guard let configuration else { throw RevenueCatServiceError.missingPublicKey }
        try configuration.validate()
#if DEBUG
        Purchases.logLevel = .debug
#endif
        if Purchases.isConfigured {
            if Purchases.shared.appUserID != customerID.uuidString.lowercased() {
                _ = try await Purchases.shared.logIn(customerID.uuidString.lowercased())
            }
        } else {
            Purchases.configure(
                withAPIKey: configuration.publicSDKKey,
                appUserID: customerID.uuidString.lowercased()
            )
        }
        self.customerID = customerID
    }

    func refreshAccess(organizationID: UUID?, challengeID: UUID?) async throws -> AccessSnapshot {
        guard let organizationID else { return .free }
        guard customerID != nil else { throw RevenueCatServiceError.notConfigured }
        _ = try? await Purchases.shared.customerInfo()
        try await requestServerRefresh(organizationID: organizationID)
        return try await workspace.accessSnapshot(organizationID: organizationID, challengeID: challengeID)
    }

    func purchase(_ requested: PurchasePackage) async throws -> PurchaseResult {
        guard customerID != nil else { throw RevenueCatServiceError.notConfigured }
        let offerings = try await Purchases.shared.offerings()
        guard let offering = offerings.all["organizer_plus_v1"] ?? offerings.current,
              let package = offering.availablePackages.first(where: {
                  $0.storeProduct.productIdentifier == requested.rawValue
              }) else {
            throw RevenueCatServiceError.packageUnavailable(requested.rawValue)
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            return result.userCancelled ? .cancelled : .purchased
        } catch {
            if (error as NSError).code == ErrorCode.paymentPendingError.rawValue { return .pending }
            throw error
        }
    }

    func restore(organizationID: UUID?, challengeID: UUID?) async throws -> AccessSnapshot {
        guard customerID != nil else { throw RevenueCatServiceError.notConfigured }
        _ = try await Purchases.shared.restorePurchases()
        return try await refreshAccess(organizationID: organizationID, challengeID: challengeID)
    }

    func redeemEventPass(organizationID: UUID, challengeID: UUID) async throws -> AccessSnapshot {
        struct Body: Encodable { let organizationId: UUID; let challengeId: UUID }
        struct Response: Decodable { let alreadyRedeemed: Bool }
        let _: Response = try await client.functions.invoke(
            "redeem-event-pass",
            options: FunctionInvokeOptions(body: Body(organizationId: organizationID, challengeId: challengeID))
        )
        var snapshot = try await workspace.accessSnapshot(organizationID: organizationID, challengeID: challengeID)
        snapshot.currentChallengeHasEventPass = true
        return snapshot
    }

    func requestServerRefresh(organizationID: UUID?) async throws {
        guard let organizationID else { return }
        struct Body: Encodable { let organizationId: UUID }
        let _: AccessRecord = try await client.functions.invoke(
            "refresh-billing", options: FunctionInvokeOptions(body: Body(organizationId: organizationID))
        )
    }
}

enum RevenueCatServiceError: LocalizedError {
    case missingPublicKey
    case testKeyInRelease
    case notConfigured
    case packageUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingPublicKey: "RevenueCat is not configured for this build."
        case .testKeyInRelease: "A RevenueCat Test Store key cannot be used in a Release build."
        case .notConfigured: "Billing will be ready after Mosaic restores your session."
        case .packageUnavailable(let id): "The RevenueCat offering does not contain \(id)."
        }
    }
}
