import XCTest
@testable import Mosaic

final class KinderThemeCatalogTests: XCTestCase {
    func testPublishedCatalogHasTenUniqueThemesPerCollection() {
        XCTAssertEqual(KinderThemeCatalog.all.count, 120)
        XCTAssertEqual(Set(KinderThemeCatalog.all.map(\.id)).count, 120)
        XCTAssertEqual(Set(KinderThemeCatalog.all.map(\.seed)).count, 120)

        for collection in KinderThemeCollection.allCases {
            XCTAssertEqual(
                KinderThemeCatalog.all.filter { $0.collection == collection }.count,
                10,
                "\(collection.title) must ship exactly ten authored artworks"
            )
        }
    }

    func testEveryThemeHasCompleteAuthoredMetadata() {
        for theme in KinderThemeCatalog.all {
            XCTAssertFalse(theme.name.isEmpty)
            XCTAssertFalse(theme.tagline.isEmpty)
            XCTAssertFalse(theme.accessibilityDescription.isEmpty)
            XCTAssertGreaterThanOrEqual(theme.tags.count, 4)
            XCTAssertEqual(theme.signatureHex.count, 3)
            XCTAssertFalse(theme.heroSymbol.isEmpty)
            XCTAssertFalse(theme.accentSymbol.isEmpty)
        }
    }

    func testUnknownThemeFallsBackToNeighborhoodQuilt() {
        XCTAssertEqual(KinderThemeCatalog.theme(id: "future-client-theme").id, "neighborhood-quilt")
    }

    func testLegacyChallengeSummaryDecodesWithFallbackTheme() throws {
        let summary = ChallengeSummary(
            id: UUID(), name: "Legacy", groupName: "Neighbors", purpose: "Care", startAt: .now,
            revealAt: .now.addingTimeInterval(3600), revealedAt: nil, serverStatus: "active",
            scheduleRevision: 1, contributionCount: 0, goal: 10, recapAvailability: .unavailable,
            recapThumbnailFilename: nil
        )
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(summary)) as? [String: Any])
        object.removeValue(forKey: "theme")
        let decoded = try JSONDecoder().decode(
            ChallengeSummary.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(decoded.theme, .fallback)
    }
}
