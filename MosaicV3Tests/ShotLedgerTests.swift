import Foundation
import Testing
@testable import Mosaic

struct ShotLedgerTests {
    @Test
    func keptPhotosConsumeShotsButDuplicateFinalizeDoesNot() {
        let id = UUID()
        var ledger = ShotLedger(limit: 12)
        let firstKeep = ledger.keep(id)
        let duplicateKeep = ledger.keep(id)
        #expect(firstKeep)
        #expect(duplicateKeep)
        #expect(ledger.used == 1)
        #expect(ledger.remaining == 11)
    }

    @Test
    func activeDeletionRestoresShotAndPostRevealDeletionDoesNot() {
        let activeID = UUID(), revealedID = UUID()
        var ledger = ShotLedger(limit: 12, keptPhotoIDs: [activeID, revealedID])
        ledger.delete(activeID, beforeReveal: true)
        #expect(ledger.remaining == 11)
        ledger.delete(revealedID, beforeReveal: false)
        #expect(ledger.remaining == 11)
    }

    @Test
    func shotExhaustionClosesKeep() {
        let ids = Set((0..<12).map { _ in UUID() })
        var ledger = ShotLedger(limit: 12, keptPhotoIDs: ids)
        #expect(!ledger.canKeep)
        let accepted = ledger.keep(UUID())
        #expect(!accepted)
    }
}
