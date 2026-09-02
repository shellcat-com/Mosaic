import Foundation
import Supabase

@MainActor
final class AppDependencies {
    static private(set) var live: AppDependencies?

    let client: SupabaseClient
    let auth: AuthServicing
    let repository: MosaicRepository
    let workspace: WorkspaceServicing
    let purchases: PurchaseServicing
    let sharedMoments: SupabaseSharedMomentRepository

    init(configuration: SupabaseConfiguration) {
        let client = MosaicSupabaseClientFactory.make(configuration: configuration)
        let workspace = SupabaseWorkspaceService(client: client)
        self.client = client
        self.auth = SupabaseAuthService(client: client)
        self.repository = SupabaseMosaicRepository(client: client)
        self.workspace = workspace
        self.purchases = RevenueCatPurchaseService(
            configuration: RevenueCatConfiguration.current,
            client: client,
            workspace: workspace
        )
        self.sharedMoments = SupabaseSharedMomentRepository(client: client)
        Self.live = self
    }
}

enum MosaicSupabaseClientFactory {
    static func make(configuration: SupabaseConfiguration) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true),
                functions: .init(decoder: MosaicJSONDecoder.make())
            )
        )
    }
}

extension SupabaseClient {
    /// Returns a usable stored session or creates the guest session Mosaic
    /// needs for invitation-based participation.
    func restoreOrCreateMosaicSession() async throws -> Session {
        if let current = auth.currentSession {
            return current.isExpired ? try await auth.session : current
        }
        return try await auth.signInAnonymously()
    }
}

enum MosaicJSONDecoder {
    static func make() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
                return date
            }
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Expected an ISO 8601 date"
            )
        }
        return decoder
    }
}
