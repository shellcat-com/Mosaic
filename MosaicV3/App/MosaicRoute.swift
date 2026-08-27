import Foundation
import Observation

enum MosaicRoute: Hashable {
    case create
    case join(prefilledCode: String?)
    case event(UUID)
    case editEvent(UUID)
    case activity(UUID)
    case contribution(UUID)
    case photo(UUID)
    case recap(UUID)
    case blockedUsers
}

enum MosaicTab: Hashable {
    case mosaics
    case camera
    case you
}

@MainActor @Observable
final class MosaicRouter {
    var selectedTab = MosaicTab.mosaics
    var mosaicsPath: [MosaicRoute] = []
    var youPath: [MosaicRoute] = []
    private(set) var pendingInvitationCode: String?
    private(set) var requestedCameraMosaicID: UUID?

    func receiveInvitation(_ rawCode: String?) {
        let code = rawCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard let code, !code.isEmpty else { return }
        pendingInvitationCode = code
    }

    func openPendingInvitation() {
        guard let code = pendingInvitationCode else { return }
        selectedTab = .mosaics
        mosaicsPath = [.join(prefilledCode: code)]
        pendingInvitationCode = nil
    }

    func openCamera(for mosaicID: UUID) {
        requestedCameraMosaicID = mosaicID
        selectedTab = .camera
    }

    func consumeCameraRequest() -> UUID? {
        defer { requestedCameraMosaicID = nil }
        return requestedCameraMosaicID
    }

    func resetPrivateState() {
        selectedTab = .mosaics
        mosaicsPath.removeAll()
        youPath.removeAll()
        requestedCameraMosaicID = nil
    }
}
