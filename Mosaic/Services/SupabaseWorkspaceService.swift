import Foundation
import Supabase

@MainActor
final class SupabaseWorkspaceService: WorkspaceServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func organizations() async throws -> [OrganizationSummary] {
        struct Member: Decodable {
            let organizationID: UUID
            let role: OrganizationRole
            enum CodingKeys: String, CodingKey { case role; case organizationID = "organization_id" }
        }
        struct Organization: Decodable { let id: UUID; let name: String }
        let memberships: [Member] = try await client.from("organization_members")
            .select("organization_id,role").execute().value
        guard !memberships.isEmpty else { return [] }
        let organizations: [Organization] = try await client.from("organizations")
            .select("id,name").in("id", values: memberships.map { $0.organizationID.uuidString }).execute().value
        let roleByID = Dictionary(uniqueKeysWithValues: memberships.map { ($0.organizationID, $0.role) })
        return organizations.compactMap { organization in
            roleByID[organization.id].map {
                OrganizationSummary(id: organization.id, name: organization.name, role: $0)
            }
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func createOrganization(name: String, organizerDisplayName: String) async throws -> (OrganizationSummary, ChallengeRecord) {
        struct Body: Encodable { let organizationName: String; let organizerDisplayName: String }
        struct OrganizationRecord: Decodable { let id: UUID; let name: String }
        struct Response: Decodable { let organization: OrganizationRecord; let challenge: ChallengeRecord }
        let response: Response = try await client.functions.invoke(
            "create-organization",
            options: FunctionInvokeOptions(body: Body(organizationName: name, organizerDisplayName: organizerDisplayName))
        )
        return (
            OrganizationSummary(id: response.organization.id, name: response.organization.name, role: .owner),
            response.challenge
        )
    }

    func createInvite(organizationID: UUID, role: OrganizationRole) async throws -> URL {
        struct Body: Encodable { let organizationId: UUID; let role: OrganizationRole }
        struct Response: Decodable { let url: URL }
        guard role != .owner else { throw WorkspaceError.ownerInviteNotAllowed }
        let response: Response = try await client.functions.invoke(
            "create-organization-invite",
            options: FunctionInvokeOptions(body: Body(organizationId: organizationID, role: role))
        )
        return response.url
    }

    func acceptInvite(token: String) async throws -> OrganizationSummary {
        struct Body: Encodable { let token: String }
        struct OrganizationRecord: Decodable { let id: UUID; let name: String }
        struct Response: Decodable { let organization: OrganizationRecord; let role: OrganizationRole }
        let response: Response = try await client.functions.invoke(
            "accept-organization-invite", options: FunctionInvokeOptions(body: Body(token: token))
        )
        return OrganizationSummary(id: response.organization.id, name: response.organization.name, role: response.role)
    }

    func accessSnapshot(organizationID: UUID, challengeID: UUID?) async throws -> AccessSnapshot {
        let record: AccessRecord = try await client.rpc(
            "organization_access_snapshot",
            params: [
                "requested_organization_id": organizationID.uuidString,
                "requested_challenge_id": challengeID?.uuidString
            ]
        ).execute().value
        return record.snapshot
    }

    func deleteOrganization(organizationID: UUID) async throws {
        struct Body: Encodable { let organizationId: UUID }
        struct Response: Decodable { let deleted: Bool }
        let _: Response = try await client.functions.invoke(
            "delete-organization", options: FunctionInvokeOptions(body: Body(organizationId: organizationID))
        )
    }

    func transferOwnership(organizationID: UUID, newOwnerID: UUID) async throws {
        struct Body: Encodable { let organizationId: UUID; let newOwnerId: UUID }
        struct Response: Decodable { let transferred: Bool }
        let _: Response = try await client.functions.invoke(
            "transfer-organization-ownership",
            options: FunctionInvokeOptions(body: Body(organizationId: organizationID, newOwnerId: newOwnerID))
        )
    }
}

enum WorkspaceError: LocalizedError {
    case ownerInviteNotAllowed
    var errorDescription: String? { "Ownership transfers use a separate confirmation flow." }
}

struct AccessRecord: Decodable, Sendable {
    let plusActive: Bool
    let plusExpiresAt: Date?
    let willRenew: Bool
    let subscriptionStatus: String
    let productID: String?
    let passBalance: Int
    let activeChallengeLimit: Int
    let participantLimit: Int
    let collaboratorLimit: Int
    let currentChallengeHasEventPass: Bool

    enum CodingKeys: String, CodingKey {
        case plusActive = "plus_active"
        case plusExpiresAt = "plus_expires_at"
        case willRenew = "will_renew"
        case subscriptionStatus = "subscription_status"
        case productID = "product_id"
        case passBalance = "pass_balance"
        case activeChallengeLimit = "active_challenge_limit"
        case participantLimit = "participant_limit"
        case collaboratorLimit = "collaborator_limit"
        case currentChallengeHasEventPass = "current_challenge_has_event_pass"
    }

    var snapshot: AccessSnapshot {
        AccessSnapshot(
            plusActive: plusActive, plusExpiresAt: plusExpiresAt, willRenew: willRenew,
            subscriptionStatus: subscriptionStatus, productID: productID, passBalance: passBalance,
            activeChallengeLimit: activeChallengeLimit, participantLimit: participantLimit,
            collaboratorLimit: collaboratorLimit, currentChallengeHasEventPass: currentChallengeHasEventPass
        )
    }
}
