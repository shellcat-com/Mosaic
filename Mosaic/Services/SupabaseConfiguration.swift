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
           url.scheme?.lowercased() == "https",
           url.host?.lowercased().hasSuffix(".supabase.co") == true,
           !configuredKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return SupabaseConfiguration(url: url, publishableKey: configuredKey)
        }
        return nil
    }
}
