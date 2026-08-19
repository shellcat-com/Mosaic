import Foundation

struct SupabaseConfiguration: Sendable {
    let url: URL
    let publishableKey: String

    static var current: SupabaseConfiguration? {
        let environment = ProcessInfo.processInfo.environment
        let configuredURL = environment["SUPABASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String
        let configuredKey = environment["SUPABASE_PUBLISHABLE_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String

        if let configuredURL,
           let configuredKey,
           !configuredURL.contains("$("),
           !configuredKey.contains("$("),
           let url = URL(string: configuredURL),
           !configuredKey.isEmpty {
            return SupabaseConfiguration(url: url, publishableKey: configuredKey)
        }

#if DEBUG
        return SupabaseConfiguration(
            url: URL(string: "http://127.0.0.1:55321")!,
            publishableKey: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
        )
#else
        return nil
#endif
    }
}
