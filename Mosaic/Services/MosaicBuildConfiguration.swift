import Foundation

enum MosaicBuildConfiguration {
    static let privacyPolicyURL = URL(string: "https://shellcat-com.github.io/Mosaic/privacy/")!
    static let termsURL = URL(string: "https://shellcat-com.github.io/Mosaic/terms/")!
    static let repositoryURL = URL(string: "https://github.com/shellcat-com/Mosaic")!

    static var billingEnabled: Bool {
        booleanValue(for: "MosaicBillingEnabled", defaultValue: true)
    }

    static var isHackathonBuild: Bool {
        booleanValue(for: "MosaicHackathonBuild", defaultValue: false)
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
