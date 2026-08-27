import AuthenticationServices
@preconcurrency import Supabase
import Foundation
import Observation

enum SessionPhase: Equatable {
    case restoring
    case signedOut
    case needsDisplayName
    case ready
    case unavailable
}

struct MosaicProfile: Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case createdAt = "created_at"
    }
}

struct MosaicAuthenticatedUser: Equatable, Sendable {
    let id: UUID
    let isAnonymous: Bool
    let appleUserID: String?
}

enum MosaicAuthEvent: Sendable {
    case signedOut
}

@MainActor
protocol MosaicAuthBackend: AnyObject {
    var currentUser: MosaicAuthenticatedUser? { get }
    var authEvents: AsyncStream<MosaicAuthEvent> { get }

    func restoreUser() async throws -> MosaicAuthenticatedUser
    func signInWithApple(_ authorization: AppleAuthorization) async throws -> MosaicAuthenticatedUser
    func profile() async throws -> MosaicProfile?
    func saveProfile(displayName: String) async throws -> MosaicProfile
    func signOut() async throws
    func deleteAccount() async throws
}

enum AppleCredentialState: Equatable, Sendable {
    case authorized
    case revoked
    case notFound
    case transferred
    case unknown
}

@MainActor
protocol AppleCredentialStateChecking {
    func state(forUserID userID: String) async -> AppleCredentialState
}

@MainActor
final class LiveAppleCredentialStateChecker: AppleCredentialStateChecking {
    private let provider = ASAuthorizationAppleIDProvider()

    func state(forUserID userID: String) async -> AppleCredentialState {
        await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: userID) { state, error in
                guard error == nil else {
                    continuation.resume(returning: .unknown)
                    return
                }
                switch state {
                case .authorized: continuation.resume(returning: .authorized)
                case .revoked: continuation.resume(returning: .revoked)
                case .notFound: continuation.resume(returning: .notFound)
                case .transferred: continuation.resume(returning: .transferred)
                @unknown default: continuation.resume(returning: .unknown)
                }
            }
        }
    }
}

@MainActor
final class SupabaseMosaicAuthBackend: MosaicAuthBackend {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    var currentUser: MosaicAuthenticatedUser? {
        client.auth.currentSession.map { authenticatedUser(from: $0.user) }
    }

    var authEvents: AsyncStream<MosaicAuthEvent> {
        AsyncStream { continuation in
            let task = Task { [client] in
                for await change in client.auth.authStateChanges {
                    guard !Task.isCancelled else { break }
                    if change.event == .signedOut || change.event == .userDeleted {
                        continuation.yield(.signedOut)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func restoreUser() async throws -> MosaicAuthenticatedUser {
        authenticatedUser(from: try await client.auth.session.user)
    }

    func signInWithApple(_ authorization: AppleAuthorization) async throws -> MosaicAuthenticatedUser {
        let credentials = OpenIDConnectCredentials(
            provider: .apple,
            idToken: authorization.identityToken,
            nonce: authorization.rawNonce
        )
        return authenticatedUser(from: try await client.auth.signInWithIdToken(credentials: credentials).user)
    }

    func profile() async throws -> MosaicProfile? {
        struct Envelope: Decodable { let profile: MosaicProfile? }
        let envelope: Envelope = try await client.rpc("v3_auth_profile").execute().value
        return envelope.profile
    }

    func saveProfile(displayName: String) async throws -> MosaicProfile {
        struct Parameters: Encodable {
            let pDisplayName: String
            enum CodingKeys: String, CodingKey { case pDisplayName = "p_display_name" }
        }
        return try await client.rpc(
            "v3_auth_save_profile",
            params: Parameters(pDisplayName: displayName)
        ).execute().value
    }

    func signOut() async throws {
        try await client.auth.signOut(scope: .local)
    }

    func deleteAccount() async throws {
        struct Deleted: Decodable { let deleted: Bool }
        let response: Deleted = try await client.functions.invoke("delete-account")
        guard response.deleted else { throw MosaicAPIError.invalidResponse }
    }

    private func authenticatedUser(from user: User) -> MosaicAuthenticatedUser {
        let appleUserID = user.identities?.first(where: { $0.provider == "apple" })?.id
        return .init(id: user.id, isAnonymous: user.isAnonymous, appleUserID: appleUserID)
    }
}

@MainActor @Observable
final class SessionStore {
    private let backend: any MosaicAuthBackend
    private let credentialChecker: any AppleCredentialStateChecking
    private let showcaseUserID: UUID?
    @ObservationIgnored private var authEventTask: Task<Void, Never>?
    @ObservationIgnored private var revocationTask: Task<Void, Never>?
    private(set) var phase = SessionPhase.restoring
    private(set) var profile: MosaicProfile?
    var suggestedDisplayName = ""
    var message: String?
    var isWorking = false

    convenience init(client: SupabaseClient, showcaseProfile: MosaicProfile? = nil) {
        self.init(
            backend: SupabaseMosaicAuthBackend(client: client),
            credentialChecker: LiveAppleCredentialStateChecker(),
            showcaseProfile: showcaseProfile
        )
    }

    init(
        backend: any MosaicAuthBackend,
        credentialChecker: any AppleCredentialStateChecking,
        showcaseProfile: MosaicProfile? = nil
    ) {
        self.backend = backend
        self.credentialChecker = credentialChecker
        self.showcaseUserID = showcaseProfile?.id
        if let showcaseProfile {
            profile = showcaseProfile
            suggestedDisplayName = showcaseProfile.displayName
            phase = .ready
        }
    }

    var userID: UUID? { showcaseUserID ?? backend.currentUser?.id }
    var isReady: Bool { phase == .ready }

    func bootstrap() async {
        if phase == .ready { return }
        startMonitoringAuthentication()
        message = nil

        guard backend.currentUser != nil else {
            showSignedOut()
            return
        }

        do {
            let user = try await backend.restoreUser()
            guard await validateAppleAccount(user) else { return }
            await loadProfile()
        } catch {
            if backend.currentUser == nil {
                showSignedOut()
            } else {
                showUnavailable()
            }
        }
    }

    func retry() async {
        phase = .restoring
        await bootstrap()
    }

    func completeAppleAuthorization(_ authorization: AppleAuthorization) async {
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            let user = try await backend.signInWithApple(authorization)
            guard !user.isAnonymous,
                  user.appleUserID == authorization.appleUserID else {
                try? await backend.signOut()
                showSignedOut(message: "Mosaic requires a valid Sign in with Apple account.")
                return
            }
            suggestedDisplayName = authorization.capturedName ?? ""
            await loadProfile()
        } catch {
            showSignedOut(message: userFacingMessage(for: error))
        }
    }

    func saveDisplayName(_ value: String) async {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard userID != nil, (2...40).contains(cleaned.count), !cleaned.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            message = "Choose a display name between 2 and 40 characters."
            return
        }
        isWorking = true
        message = nil
        defer { isWorking = false }
        if let showcaseUserID {
            profile = MosaicProfile(id: showcaseUserID, displayName: cleaned, createdAt: profile?.createdAt ?? .now)
            phase = .ready
            return
        }
        do {
            profile = try await backend.saveProfile(displayName: cleaned)
            suggestedDisplayName = cleaned
            phase = .ready
        } catch {
            message = userFacingMessage(for: error)
        }
    }

    func signOut() async {
        if showcaseUserID != nil {
            showSignedOut()
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await backend.signOut()
            showSignedOut()
        } catch {
            showUnavailable(message: "We couldn't sign you out. Try again when you're connected.")
        }
    }

    func deleteAccount() async throws {
        if showcaseUserID != nil {
            showSignedOut()
            return
        }
        try await backend.deleteAccount()
        try? await backend.signOut()
        showSignedOut()
    }

    private func loadProfile() async {
        do {
            if let value = try await backend.profile(),
               !value.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profile = value
                suggestedDisplayName = value.displayName
                phase = .ready
            } else {
                profile = nil
                phase = .needsDisplayName
            }
        } catch {
            showUnavailable(message: userFacingMessage(for: error))
        }
    }

    private func validateAppleAccount(_ user: MosaicAuthenticatedUser) async -> Bool {
        guard !user.isAnonymous, let appleUserID = user.appleUserID else {
            try? await backend.signOut()
            showSignedOut(message: "Sign in with Apple to continue.")
            return false
        }

        switch await credentialChecker.state(forUserID: appleUserID) {
        case .revoked, .notFound, .transferred:
            try? await backend.signOut()
            showSignedOut(message: "Your Apple authorization changed. Sign in again to continue.")
            return false
        case .authorized, .unknown:
            return true
        }
    }

    private func startMonitoringAuthentication() {
        if authEventTask == nil {
            authEventTask = Task { [weak self, backend] in
                for await event in backend.authEvents {
                    guard !Task.isCancelled else { break }
                    if case .signedOut = event { self?.showSignedOut() }
                }
            }
        }

        if revocationTask == nil {
            revocationTask = Task { [weak self] in
                let notifications = NotificationCenter.default.notifications(
                    named: ASAuthorizationAppleIDProvider.credentialRevokedNotification
                )
                for await _ in notifications {
                    guard !Task.isCancelled else { break }
                    await self?.handleAppleCredentialRevocation()
                }
            }
        }
    }

    private func handleAppleCredentialRevocation() async {
        try? await backend.signOut()
        showSignedOut(message: "Sign in again because Mosaic's Apple authorization was revoked.")
    }

    private func showSignedOut(message: String? = nil) {
        profile = nil
        suggestedDisplayName = ""
        self.message = message
        phase = .signedOut
    }

    private func showUnavailable(message: String = "We couldn't reach Mosaic. Check your connection and try again.") {
        self.message = message
        phase = .unavailable
    }

    private func userFacingMessage(for error: any Error) -> String {
        let description = error.localizedDescription.lowercased()
        if description.contains("apple_account_required") {
            return "Sign in with Apple to continue."
        }
        if description.contains("invalid_display_name") {
            return "Choose a display name between 2 and 40 characters."
        }
        return "We couldn't reach Mosaic. Check your connection and try again."
    }
}
