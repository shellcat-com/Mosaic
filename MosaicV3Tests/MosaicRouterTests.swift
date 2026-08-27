import Foundation
import Testing
@testable import Mosaic

@MainActor
struct MosaicRouterTests {
    @Test
    func invitationReplacesStaleMosaicPath() {
        let router = MosaicRouter()
        router.mosaicsPath = [.create]

        router.receiveInvitation(" ab12cd ")
        router.openPendingInvitation()

        #expect(router.selectedTab == .mosaics)
        #expect(router.mosaicsPath == [.join(prefilledCode: "AB12CD")])
        #expect(router.pendingInvitationCode == nil)
    }

    @Test
    func cameraRequestSelectsTabAndIsConsumedOnce() {
        let router = MosaicRouter()
        let mosaicID = UUID()

        router.openCamera(for: mosaicID)

        #expect(router.selectedTab == .camera)
        #expect(router.consumeCameraRequest() == mosaicID)
        #expect(router.consumeCameraRequest() == nil)
    }

    @Test
    func resetClearsPrivateNavigationAndCameraState() {
        let router = MosaicRouter()
        router.mosaicsPath = [.create]
        router.youPath = [.blockedUsers]
        router.openCamera(for: UUID())

        router.resetPrivateState()

        #expect(router.selectedTab == .mosaics)
        #expect(router.mosaicsPath.isEmpty)
        #expect(router.youPath.isEmpty)
        #expect(router.consumeCameraRequest() == nil)
    }
}
