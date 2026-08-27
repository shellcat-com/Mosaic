import Foundation
import Testing
@testable import Mosaic

struct BillingModelTests {
    @Test
    func releaseConfigurationRejectsTestStoreKey() {
        let configuration = RevenueCatConfiguration(publicSDKKey: "test_public_demo", billingEnabled: true)
        #expect(throws: BillingConfigurationError.testKeyInRelease) {
            try configuration.validate(isDebugBuild: false)
        }
    }

    @Test
    func debugConfigurationAcceptsTestStorePublicKey() throws {
        let configuration = RevenueCatConfiguration(publicSDKKey: "test_public_demo", billingEnabled: true)
        try configuration.validate(isDebugBuild: true)
    }

    @Test
    func premiumRulesNeverRestrictParticipants() {
        #expect(BillingSnapshot.free.capabilities == .free)
        #expect(BillingSnapshot.free.capabilities.maximumTileGoal == 25)
        #expect(BillingSnapshot.free.capabilities.availableFilmLooks == [.sunwashed])
        let plus = BillingSnapshot(
            plusActive: true, subscriptionState: .active,
            productID: MosaicBillingCatalog.annualProductID, expiresAt: .now,
            willRenew: true, passBalance: 0, synchronizedAt: .now
        )
        #expect(plus.capabilities == .premium)
        #expect(plus.capabilities.maximumTileGoal == 100)
        #expect(plus.capabilities.maximumShotLimit == 36)
    }

    @Test
    func draftPremiumClassificationMatchesServerContract() {
        var draft = MosaicDraft()
        #expect(!draft.requiresPremiumAccess)
        draft.goal = 36
        #expect(draft.requiresPremiumAccess)
        draft.goal = 25
        draft.shotLimit = 24
        #expect(draft.requiresPremiumAccess)
        draft.shotLimit = 12
        draft.filmLookID = .garden
        #expect(draft.requiresPremiumAccess)
    }

    @Test
    func savingsRequireComparableLocalizedCurrencies() {
        let annual = MonetizationPackage(
            packageIdentifier: "$rc_annual", productIdentifier: "annual", localizedPrice: "$48",
            price: 48, currencyCode: "USD", period: "per year", introductoryOffer: nil, kind: .annual
        )
        let monthly = MonetizationPackage(
            packageIdentifier: "$rc_monthly", productIdentifier: "monthly", localizedPrice: "$5",
            price: 5, currencyCode: "USD", period: "per month", introductoryOffer: nil, kind: .monthly
        )
        #expect(MosaicPriceMath.annualSavingsPercent(annual: annual, monthly: monthly) == 20)
        let euros = MonetizationPackage(
            packageIdentifier: "$rc_monthly", productIdentifier: "monthly-eur", localizedPrice: "€5",
            price: 5, currencyCode: "EUR", period: "per month", introductoryOffer: nil, kind: .monthly
        )
        #expect(MosaicPriceMath.annualSavingsPercent(annual: annual, monthly: euros) == nil)
    }

    @Test
    func capturedAccessSourceSurvivesCodableRoundTrip() throws {
        var summary = MosaicSummary(
            id: UUID(), name: "Premium Mosaic", communityName: "Students", description: "",
            startAt: .now, revealAt: .now.addingTimeInterval(3_600), goal: 100,
            contributionCount: 0, photoCount: 0, filmLookID: .afterglow, shotLimit: 36,
            artwork: CuratedArtwork.collection[0], isCreator: true
        )
        summary.accessSource = .eventPass
        summary.premiumCapabilities = .premium
        let decoded = try JSONDecoder().decode(MosaicSummary.self, from: JSONEncoder().encode(summary))
        #expect(decoded.accessSource == .eventPass)
        #expect(decoded.premiumCapabilities == .premium)
    }
}

#if DEBUG
@MainActor
struct BillingStoreTests {
    @Test(arguments: [BillingPurchaseOutcome.cancelled, .pending, .purchased])
    func purchaseTransitionsAreDeterministic(_ outcome: BillingPurchaseOutcome) async {
        let purchases = MockRevenueCatPurchasing(purchaseOutcome: outcome)
        let api = ShowcaseMosaicAPI(events: MosaicShowcaseFixtures.makeEvents())
        let store = BillingStore(purchases: purchases, api: api)
        await store.configure(userID: MosaicShowcaseFixtures.memberID)

        await store.purchaseSelected()

        switch outcome {
        case .cancelled: #expect(store.actionState == .idle)
        case .pending: #expect(store.actionState == .pending)
        case .purchased: #expect(store.actionState == .success)
        }
    }

    @Test
    func identityIsLowercaseAndLogoutClearsPrivateBillingState() async {
        let purchases = MockRevenueCatPurchasing()
        let api = ShowcaseMosaicAPI(events: [])
        let store = BillingStore(purchases: purchases, api: api)
        let userID = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!
        await store.configure(userID: userID)
        #expect(purchases.configuredUserID == userID.uuidString.lowercased())
        await store.logOut()
        #expect(purchases.configuredUserID == nil)
        #expect(store.snapshot == .free)
    }
}
#endif
