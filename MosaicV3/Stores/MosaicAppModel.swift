@preconcurrency import Supabase
import Foundation
import Observation

private struct MosaicEphemeralAuthStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws {}
    func retrieve(key: String) throws -> Data? { nil }
    func remove(key: String) throws {}
}

@MainActor @Observable
final class MosaicAppModel {
    let client: SupabaseClient
    let api: any MosaicAPI
    let session: SessionStore
    let library: MosaicLibraryStore
    let detail: MosaicDetailStore
    let camera: CameraStore
    let router: MosaicRouter
    let billing: BillingStore

    init(configuration: MosaicSupabaseConfiguration? = .current) {
        let fallbackURL = URL(string: "https://invalid.local") ?? URL(fileURLWithPath: "/")
        let effective = configuration ?? .init(url: fallbackURL, publishableKey: "invalid")
        let client = MosaicSupabaseFactory.make(configuration: effective)
        let api = SupabaseMosaicAPI(client: client)
        self.client = client
        self.api = api
        self.session = SessionStore(client: client)
        self.library = MosaicLibraryStore(api: api)
        self.detail = MosaicDetailStore(api: api)
        self.camera = CameraStore(api: api)
        self.router = MosaicRouter()
        self.billing = BillingStore(purchases: RevenueCatBillingService(), api: api)
    }

    init(showcaseAPI: any MosaicAPI, profile: MosaicProfile) {
        let showcaseURL = URL(string: "https://showcase.invalid") ?? URL(fileURLWithPath: "/")
        let client = SupabaseClient(
            supabaseURL: showcaseURL,
            supabaseKey: "showcase",
            options: .init(auth: .init(storage: MosaicEphemeralAuthStorage(), autoRefreshToken: false))
        )
        self.client = client
        self.api = showcaseAPI
        self.session = SessionStore(client: client, showcaseProfile: profile)
        self.library = MosaicLibraryStore(api: showcaseAPI)
        self.detail = MosaicDetailStore(api: showcaseAPI)
        self.camera = CameraStore(api: showcaseAPI)
        self.router = MosaicRouter()
        self.billing = BillingStore(purchases: MockRevenueCatPurchasing(), api: showcaseAPI)
    }

    func bootstrap() async {
        await session.bootstrap()
        if session.isReady {
            await configureAuthenticatedServices()
            await library.refresh()
        }
    }

    func configureAuthenticatedServices() async {
        guard let userID = session.userID else { return }
        await billing.configure(userID: userID)
    }

    func signOut() async {
        router.resetPrivateState()
        camera.select(nil)
        await billing.logOut()
        await session.signOut()
    }

    func deleteAccount() async throws {
        router.resetPrivateState()
        camera.select(nil)
        await billing.logOut()
        try await session.deleteAccount()
    }

    func handle(url: URL) {
        guard url.scheme == "mosaic" else { return }
        if url.host == "join" {
            router.receiveInvitation(url.pathComponents.last)
        }
    }
}
