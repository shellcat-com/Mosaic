import Foundation

enum AppSessionState: Equatable, Sendable {
    case loading
    case guest(userID: UUID)
    case authenticated(userID: UUID)
    case failed(message: String)

    var userID: UUID? {
        switch self {
        case .guest(let id), .authenticated(let id): id
        case .loading, .failed: nil
        }
    }

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}

enum OrganizationRole: String, Codable, CaseIterable, Sendable {
    case owner
    case admin
    case reviewer

    var canManageBilling: Bool { self == .owner }
    var canManageCollaborators: Bool { self == .owner }
    var canManageChallenges: Bool { self == .owner || self == .admin }
    var canModerate: Bool { true }
}

enum PremiumFeature: String, CaseIterable, Sendable {
    case customArtwork
    case customMissions
    case collaborators
    case additionalChallenge
    case advancedModeration
    case recapEditor
    case hdArtwork
    case posterExport
}

struct AccessSnapshot: Equatable, Sendable {
    var plusActive: Bool
    var plusExpiresAt: Date?
    var willRenew: Bool
    var subscriptionStatus: String
    var productID: String?
    var passBalance: Int
    var activeChallengeLimit: Int
    var participantLimit: Int
    var collaboratorLimit: Int
    var currentChallengeHasEventPass: Bool

    static let free = AccessSnapshot(
        plusActive: false,
        plusExpiresAt: nil,
        willRenew: false,
        subscriptionStatus: "none",
        productID: nil,
        passBalance: 0,
        activeChallengeLimit: 1,
        participantLimit: 25,
        collaboratorLimit: 0,
        currentChallengeHasEventPass: false
    )

    func allows(_ feature: PremiumFeature) -> Bool {
        plusActive || currentChallengeHasEventPass
    }

    var planName: String {
        if plusActive { return "Organizer Plus" }
        if currentChallengeHasEventPass { return "Mosaic Event Pass" }
        return "Free"
    }
}

struct OrganizationSummary: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let role: OrganizationRole
}

struct AppleAuthorization: Sendable {
    let identityToken: String
    let rawNonce: String
    let givenName: String?
    let familyName: String?

    var capturedDisplayName: String? {
        [givenName, familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .nilIfEmpty
    }
}

enum PurchasePackage: String, CaseIterable, Identifiable, Sendable {
    case annual = "organizer_annual"
    case monthly = "organizer_monthly"
    case eventPass = "mosaic_event_pass"
    var id: String { rawValue }
}

enum PurchaseResult: Equatable, Sendable {
    case purchased
    case cancelled
    case pending
}

@MainActor
protocol AuthServicing: AnyObject {
    var clientUserID: UUID? { get }
    func restoreOrCreateGuest() async throws -> AppSessionState
    func signInOrLinkWithApple(_ authorization: AppleAuthorization) async throws -> AppSessionState
    func switchAccount(with authorization: AppleAuthorization) async throws -> AppSessionState
    func signOutToFreshGuest() async throws -> AppSessionState
    func deleteAccount() async throws -> AppSessionState
}

@MainActor
protocol PurchaseServicing: AnyObject {
    func configure(customerID: UUID) async throws
    func refreshAccess(organizationID: UUID?, challengeID: UUID?) async throws -> AccessSnapshot
    func purchase(_ package: PurchasePackage) async throws -> PurchaseResult
    func restore(organizationID: UUID?, challengeID: UUID?) async throws -> AccessSnapshot
    func redeemEventPass(organizationID: UUID, challengeID: UUID) async throws -> AccessSnapshot
}

@MainActor
protocol WorkspaceServicing: AnyObject {
    func organizations() async throws -> [OrganizationSummary]
    func createOrganization(name: String, organizerDisplayName: String) async throws -> (OrganizationSummary, ChallengeRecord)
    func createInvite(organizationID: UUID, role: OrganizationRole) async throws -> URL
    func acceptInvite(token: String) async throws -> OrganizationSummary
    func accessSnapshot(organizationID: UUID, challengeID: UUID?) async throws -> AccessSnapshot
    func deleteOrganization(organizationID: UUID) async throws
    func transferOwnership(organizationID: UUID, newOwnerID: UUID) async throws
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
