import Foundation
import Testing
@testable import Mosaic

@MainActor
struct SessionStoreTests {
    private let userID = UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!

    @Test
    func bootstrapWithoutStoredSessionShowsSignIn() async {
        let backend = TestAuthBackend()
        let store = makeStore(backend: backend)

        await store.bootstrap()

        #expect(store.phase == .signedOut)
        #expect(store.userID == nil)
    }

    @Test
    func anonymousSessionIsRejectedAndRemoved() async {
        let backend = TestAuthBackend()
        backend.current = .init(id: userID, isAnonymous: true, appleUserID: nil)
        let store = makeStore(backend: backend)

        await store.bootstrap()

        #expect(store.phase == .signedOut)
        #expect(backend.signOutCount == 1)
        #expect(store.message == "Sign in with Apple to continue.")
    }

    @Test
    func authorizedAppleSessionRestoresExistingProfile() async {
        let backend = TestAuthBackend()
        backend.current = appleUser()
        backend.storedProfile = .init(id: userID, displayName: "Ada", createdAt: .now)
        let store = makeStore(backend: backend)

        await store.bootstrap()

        #expect(store.phase == .ready)
        #expect(store.profile?.displayName == "Ada")
    }

    @Test
    func newAppleAccountRequiresDisplayName() async {
        let backend = TestAuthBackend()
        backend.current = appleUser()
        let store = makeStore(backend: backend)

        await store.bootstrap()

        #expect(store.phase == .needsDisplayName)
    }

    @Test
    func revokedAppleCredentialSignsOutLocally() async {
        let backend = TestAuthBackend()
        backend.current = appleUser()
        let checker = TestAppleCredentialChecker(state: .revoked)
        let store = SessionStore(backend: backend, credentialChecker: checker)

        await store.bootstrap()

        #expect(store.phase == .signedOut)
        #expect(backend.signOutCount == 1)
        #expect(store.message?.contains("authorization changed") == true)
    }

    @Test
    func signInRejectsMismatchedAppleSubject() async {
        let backend = TestAuthBackend()
        backend.signInUser = .init(id: userID, isAnonymous: false, appleUserID: "different-subject")
        let store = makeStore(backend: backend)

        await store.completeAppleAuthorization(authorization())

        #expect(store.phase == .signedOut)
        #expect(backend.signOutCount == 1)
    }

    @Test
    func displayNameIsNormalizedAndSavedThroughAuthBoundary() async {
        let backend = TestAuthBackend()
        backend.current = appleUser()
        let store = makeStore(backend: backend)

        await store.saveDisplayName("  Ada Lovelace  ")

        #expect(backend.savedDisplayName == "Ada Lovelace")
        #expect(store.phase == .ready)
        #expect(store.profile?.displayName == "Ada Lovelace")
    }

    @Test
    func profileFailureOffersRetryWithoutDiscardingSession() async {
        let backend = TestAuthBackend()
        backend.current = appleUser()
        backend.profileError = TestFailure.offline
        let store = makeStore(backend: backend)

        await store.bootstrap()

        #expect(store.phase == .unavailable)
        #expect(store.userID == userID)
    }

    @Test
    func accountDeletionUsesServerBoundaryAndClearsSession() async throws {
        let backend = TestAuthBackend()
        backend.current = appleUser()
        let store = makeStore(backend: backend)

        try await store.deleteAccount()

        #expect(backend.deleteCount == 1)
        #expect(store.phase == .signedOut)
        #expect(store.userID == nil)
    }

    private func makeStore(backend: TestAuthBackend) -> SessionStore {
        SessionStore(backend: backend, credentialChecker: TestAppleCredentialChecker(state: .authorized))
    }

    private func appleUser() -> MosaicAuthenticatedUser {
        .init(id: userID, isAnonymous: false, appleUserID: "apple-subject")
    }

    private func authorization() -> AppleAuthorization {
        .init(identityToken: "token", rawNonce: "nonce", appleUserID: "apple-subject", capturedName: "Ada")
    }
}

private enum TestFailure: Error { case offline }

@MainActor
private final class TestAppleCredentialChecker: AppleCredentialStateChecking {
    let result: AppleCredentialState
    init(state: AppleCredentialState) { result = state }
    func state(forUserID userID: String) async -> AppleCredentialState { result }
}

@MainActor
private final class TestAuthBackend: MosaicAuthBackend {
    var current: MosaicAuthenticatedUser?
    var signInUser: MosaicAuthenticatedUser?
    var storedProfile: MosaicProfile?
    var profileError: (any Error)?
    var savedDisplayName: String?
    var signOutCount = 0
    var deleteCount = 0

    var currentUser: MosaicAuthenticatedUser? { current }
    var authEvents: AsyncStream<MosaicAuthEvent> {
        AsyncStream { $0.finish() }
    }

    func restoreUser() async throws -> MosaicAuthenticatedUser {
        guard let current else { throw TestFailure.offline }
        return current
    }

    func signInWithApple(_ authorization: AppleAuthorization) async throws -> MosaicAuthenticatedUser {
        let user = signInUser ?? .init(id: UUID(), isAnonymous: false, appleUserID: authorization.appleUserID)
        current = user
        return user
    }

    func profile() async throws -> MosaicProfile? {
        if let profileError { throw profileError }
        return storedProfile
    }

    func saveProfile(displayName: String) async throws -> MosaicProfile {
        savedDisplayName = displayName
        let value = MosaicProfile(id: current?.id ?? UUID(), displayName: displayName, createdAt: .now)
        storedProfile = value
        return value
    }

    func signOut() async throws {
        signOutCount += 1
        current = nil
    }

    func deleteAccount() async throws {
        deleteCount += 1
        current = nil
    }
}
