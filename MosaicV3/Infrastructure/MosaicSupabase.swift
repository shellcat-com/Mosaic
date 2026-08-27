@preconcurrency import Supabase
import Foundation

struct MosaicSupabaseConfiguration: Sendable {
    let url: URL
    let publishableKey: String

    static var current: Self? {
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: rawURL),
              let key = Bundle.main.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
              !key.isEmpty else { return nil }
        return .init(url: url, publishableKey: key)
    }
}

enum MosaicSupabaseFactory {
    static func make(configuration: MosaicSupabaseConfiguration) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
        )
    }
}

enum MosaicAPIError: LocalizedError, Equatable {
    case configurationMissing
    case accountRequired
    case invalidInvitation
    case joiningClosed
    case contributionClosed
    case alreadyCompleted
    case boardFull
    case shotLimitReached
    case sensitivePhoto
    case premiumRequired
    case freeCreationLimit
    case invalidResponse
    case message(String)

    var errorDescription: String? {
        switch self {
        case .configurationMissing: "Mosaic's Supabase configuration is missing."
        case .accountRequired: "Sign in with Apple before continuing."
        case .invalidInvitation: "That Mosaic invitation is not valid."
        case .joiningClosed: "Joining closed when this Mosaic revealed."
        case .contributionClosed: "Kindness contributions are closed."
        case .alreadyCompleted: "You already took part in this activity."
        case .boardFull: "The kindness board is complete. The camera stays open until reveal."
        case .shotLimitReached: "You have used every shot in this Mosaic."
        case .sensitivePhoto: "This photo could not be added because it may contain sensitive content."
        case .premiumRequired: "This creation choice needs Mosaic Plus or one Event Pass."
        case .freeCreationLimit: "Reveal your current Mosaic or choose Plus to create another."
        case .invalidResponse: "Mosaic received an unexpected server response."
        case .message(let value): value
        }
    }
}

struct AppleAuthorization: Sendable {
    let identityToken: String
    let rawNonce: String
    let appleUserID: String
    let capturedName: String?
}
