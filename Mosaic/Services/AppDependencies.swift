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
        let client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.publishableKey)
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
