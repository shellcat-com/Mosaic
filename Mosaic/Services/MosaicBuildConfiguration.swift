import Foundation

enum MosaicBuildConfiguration {
    static let privacyPolicyURL = URL(string: "https://shellcat-com.github.io/Mosaic/privacy/")!
    static let termsURL = URL(string: "https://shellcat-com.github.io/Mosaic/terms/")!
    static let repositoryURL = URL(string: "https://github.com/shellcat-com/Mosaic")!

    static func invitationLandingURL(code: String) -> URL {
        var components = URLComponents(string: "https://shellcat-com.github.io/Mosaic/")!
        components.queryItems = [URLQueryItem(name: "join", value: code.uppercased())]
        return components.url!
    }

    static func invitationShareText(challengeName: String, code: String) -> String {
        "Join \(challengeName) in Mosaic with code \(code.uppercased()): \(invitationLandingURL(code: code).absoluteString)"
    }

    static var billingEnabled: Bool {
        booleanValue(for: "MosaicBillingEnabled", defaultValue: true)
    }

    static var isHackathonBuild: Bool {
        booleanValue(for: "MosaicHackathonBuild", defaultValue: false)
    }

    static var remotePushEnabled: Bool {
        booleanValue(for: "MosaicRemotePushEnabled", defaultValue: false)
    }

    static var submissionName: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MosaicSubmissionName") as? String else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !normalized.contains("$(") else { return nil }
        return normalized
    }

    private static func booleanValue(for key: String, defaultValue: Bool) -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else {
            return defaultValue
        }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes": return true
            case "0", "false", "no": return false
            default: break
            }
        }
        return defaultValue
    }
}
