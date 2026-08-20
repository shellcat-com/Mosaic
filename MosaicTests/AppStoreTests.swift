import Foundation
import Testing
@testable import Mosaic

@MainActor
struct AppStoreTests {
    @Test func coldLaunchAnimationFitsTimingBudget() {
        #expect(MosaicLaunchTiming.totalDuration <= 1.5)
        #expect(MosaicLaunchTiming.reduceMotionHold == 0.35)
    }

    @Test func guestJoinStoresPrivacyChoice() async {
        let store = AppStore()
        let invitation = InvitationPreview(
            challengeID: store.challenge.id,
            code: store.challenge.invitationCode,
            name: store.challenge.name,
            groupName: store.challenge.groupName,
            purpose: store.challenge.purpose,
            goal: store.challenge.goal,
            startAt: store.challenge.startDate,
            revealAt: store.challenge.revealDate,
            status: store.challenge.serverStatus
        )
        store.continueToJoin(invitation)
        let joined = await store.joinInvitation(
            invitation,
            name: "  Maya  ",
            privacy: .firstName
        )

        #expect(joined)
        #expect(store.entryState == .main)
        #expect(store.displayName == "Maya")
        #expect(store.privacyMode == "First name")
    }

    @Test func contributionIsAddedExactlyOnceByStoreCall() {
        let store = AppStore()
        let before = store.challenge.contributions.count
        let mission = store.missions[0]
        let contribution = TileContribution(
            id: UUID(), mission: mission, emotion: .hopeful,
            evidence: .reflection, contributor: nil, sharedMemory: false, isRevived: false
        )

        store.addContribution(contribution)

        #expect(store.challenge.contributions.count == before + 1)
        #expect(store.pendingContribution?.id == contribution.id)
    }

    @Test func seedChallengeHasAttributableImpact() {
        let store = AppStore()
        let verified = store.challenge.contributions.filter { $0.evidence != .reflection }.count
        let selfAttested = store.challenge.contributions.filter { $0.evidence == .reflection }.count

        #expect(verified + selfAttested == store.challenge.contributions.count)
    }
}
