import Foundation
import Testing
@testable import Mosaic

struct AccountAccessTests {
    @Test func organizationPermissionMatrix() {
        #expect(OrganizationRole.owner.canManageBilling)
        #expect(OrganizationRole.owner.canManageCollaborators)
        #expect(OrganizationRole.admin.canManageChallenges)
        #expect(!OrganizationRole.admin.canManageBilling)
        #expect(OrganizationRole.reviewer.canModerate)
        #expect(!OrganizationRole.reviewer.canManageChallenges)
    }

    @Test func freePlusAndPassFeatureGates() {
        let free = AccessSnapshot.free
        #expect(!free.allows(.customArtwork))
        #expect(free.participantLimit == 25)

        var plus = free
        plus.plusActive = true
        plus.participantLimit = 250
        plus.collaboratorLimit = 5
        #expect(plus.allows(.posterExport))
        #expect(plus.participantLimit == 250)

        var pass = free
        pass.currentChallengeHasEventPass = true
        pass.participantLimit = 100
        pass.collaboratorLimit = 2
        #expect(pass.allows(.recapEditor))
        #expect(pass.collaboratorLimit == 2)
    }

    @Test func sessionStateDistinguishesGuestFromAccount() {
        let id = UUID()
        #expect(!AppSessionState.guest(userID: id).isAuthenticated)
        #expect(AppSessionState.authenticated(userID: id).isAuthenticated)
        #expect(AppSessionState.authenticated(userID: id).userID == id)
    }

    @Test func nonceHashIsStableAndDoesNotExposeRawNonce() {
        let raw = "mosaic-nonce"
        let hash = AppleNonce.hashed(raw)
        #expect(hash == AppleNonce.hashed(raw))
        #expect(hash != raw)
        #expect(hash.count == 64)
    }
}
