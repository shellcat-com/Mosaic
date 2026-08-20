import UIKit
@preconcurrency import UserNotifications

extension Notification.Name {
    static let mosaicRemoteDeviceToken = Notification.Name("mosaic.remote-device-token")
    static let mosaicNotificationDeepLink = Notification.Name("mosaic.notification-deep-link")
}

final class MosaicAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .mosaicRemoteDeviceToken, object: token)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let rawURL = response.notification.request.content.userInfo["deep_link"] as? String,
              let url = URL(string: rawURL)
        else { return }
        NotificationCenter.default.post(name: .mosaicNotificationDeepLink, object: url)
    }
}
