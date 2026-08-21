import CryptoKit
import Foundation
import Security
import Supabase

@MainActor
final class SupabaseAuthService: AuthServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    var clientUserID: UUID? { client.auth.currentSession?.user.id }

    func restoreOrCreateGuest() async throws -> AppSessionState {
        let session: Session
        if let current = client.auth.currentSession {
            session = current
        } else {
            session = try await client.auth.signInAnonymously()
        }
        return Self.state(for: session)
    }

    func signInOrLinkWithApple(_ authorization: AppleAuthorization) async throws -> AppSessionState {
        let credentials = OpenIDConnectCredentials(
            provider: .apple,
            idToken: authorization.identityToken,
            nonce: authorization.rawNonce
        )
        if let guestSession = client.auth.currentSession, guestSession.user.isAnonymous {
            do {
                let linked = try await client.auth.linkIdentityWithIdToken(credentials: credentials)
                try await updateCapturedName(authorization.capturedDisplayName)
                return Self.state(for: linked)
            } catch AuthError.api(_, let errorCode, _, _) where errorCode == .identityAlreadyExists {
                let target = try await client.auth.signInWithIdToken(credentials: credentials)
                struct MergeBody: Encodable {
                    let guestAccessToken: String
                    let targetAccessToken: String
                }
                struct MergeResponse: Decodable { let merged: Bool }
                let _: MergeResponse = try await client.functions.invoke(
                    "merge-guest-account",
                    options: FunctionInvokeOptions(body: MergeBody(
                        guestAccessToken: guestSession.accessToken,
                        targetAccessToken: target.accessToken
                    ))
                )
                try await updateCapturedName(authorization.capturedDisplayName)
                return Self.state(for: target)
            }
        }
        let session = try await client.auth.signInWithIdToken(credentials: credentials)
        try await updateCapturedName(authorization.capturedDisplayName)
        return Self.state(for: session)
    }

    func switchAccount(with authorization: AppleAuthorization) async throws -> AppSessionState {
        try await signInOrLinkWithApple(authorization)
    }

    func signOutToFreshGuest() async throws -> AppSessionState {
        try await client.auth.signOut(scope: .local)
        let session = try await client.auth.signInAnonymously()
        return Self.state(for: session)
    }

    func deleteAccount() async throws -> AppSessionState {
        struct Deleted: Decodable { let deleted: Bool }
        let _: Deleted = try await client.functions.invoke("delete-account")
        // The deleted JWT can no longer be refreshed; discard it locally and
        // immediately restore the guest-first experience.
        try? await client.auth.signOut(scope: .local)
        let session = try await client.auth.signInAnonymously()
        return Self.state(for: session)
    }

    private func updateCapturedName(_ displayName: String?) async throws {
        guard let displayName else { return }
        struct Body: Encodable { let displayName: String }
        struct Updated: Decodable { let ok: Bool }
        let _: Updated = try await client.functions.invoke(
            "update-profile", options: FunctionInvokeOptions(body: Body(displayName: displayName))
        )
    }

    private static func state(for session: Session) -> AppSessionState {
        session.user.isAnonymous ? .guest(userID: session.user.id) : .authenticated(userID: session.user.id)
    }
}

enum AppleNonce {
    static func make(length: Int = 32) -> String {
        precondition(length > 0)
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            precondition(status == errSecSuccess)
            for byte in bytes where remaining > 0 {
                if byte < characters.count {
                    result.append(characters[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func hashed(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
