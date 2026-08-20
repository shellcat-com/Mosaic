import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class AppStore {
    var hasJoined = false
    var displayName = ""
    var privacyMode = "First name"
    var selectedMission: Mission?
    var pendingContribution: TileContribution?
    var isOrganizer = false
    var showReveal = false
    var backendState: MosaicBackendState = .localPreview
    var backendMessage: String?
    var sandboxChallengeID: UUID?
    var showcaseChallengeID: UUID?
    var challengeLibrary: [ChallengeSummary] = []
    var notificationPreferences: [UUID: NotificationPreferences] = MosaicEventCache.loadPreferences()
    var pendingRoute: EventRoute?
    var calendarUpdateRequired: Set<UUID> = []
    var showSharedCamera = false
    var showSealedRoll = false
    var showRecapEditor = false
    var lastSealedMomentAt: Date?
    var sessionState: AppSessionState = .loading
    var organizations: [OrganizationSummary] = []
    var selectedOrganizationID: UUID?
    var accessSnapshot: AccessSnapshot = .free
    var isShowingOrganizerSetup = false
    var isShowingPaywall = false
    var paywallContext: PremiumFeature?
    var accountMessage: String?
    var latestCollaboratorInvite: URL?
    var pendingWorkspaceInviteToken: String?
    var isShowingInviteAcceptance = false
    var isShowingRecoveryPrompt = false

    var missions: [Mission] = [
        Mission(title: "Leave a kind note", detail: "Brighten someone’s day with a few kind words.", category: .encouragement, minutes: 5, effort: "Easy", evidence: [.reflection, .photo]),
        Mission(title: "Clean a shared space", detail: "Leave one small corner of your community better than you found it.", category: .community, minutes: 20, effort: "Hands-on", evidence: [.photo, .video, .organizer]),
        Mission(title: "Donate a useful item", detail: "Give something in good condition to a neighbor or local organization.", category: .giving, minutes: 15, effort: "Easy", evidence: [.photo, .receipt]),
        Mission(title: "Teach a useful skill", detail: "Share something practical that helps another person feel more capable.", category: .teaching, minutes: 30, effort: "Together", evidence: [.reflection, .video]),
        Mission(title: "Support something local", detail: "Show up for a neighborhood group, maker, or nonprofit.", category: .support, minutes: 20, effort: "Flexible", evidence: [.receipt, .photo, .organizer]),
        Mission(title: "Check in with someone", detail: "Reach out and make room for a genuine conversation.", category: .connection, minutes: 10, effort: "Quiet", evidence: [.reflection, .organizer])
    ]

    var challenge: KindnessChallenge
    @ObservationIgnored private let repository: MosaicRepository?
    @ObservationIgnored private var realtimeTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var localChallenges: [UUID: KindnessChallenge] = [:]
    @ObservationIgnored private let sharedMomentRepository: SharedMomentRepository
    @ObservationIgnored private let engagementTracker: EngagementTracking
    @ObservationIgnored private let authService: AuthServicing?
    @ObservationIgnored private let purchaseService: PurchaseServicing?
    @ObservationIgnored private let workspaceService: WorkspaceServicing?
    let localParticipantID: UUID

    init(repository: MosaicRepository? = nil) {
        self.localParticipantID = Self.persistedParticipantID()
        if let repository {
            self.repository = repository
            self.sharedMomentRepository = LocalSharedMomentRepository()
            self.engagementTracker = NoopEngagementTracker()
            self.authService = nil
            self.purchaseService = nil
            self.workspaceService = nil
        } else if NSClassFromString("XCTestCase") == nil, let configuration = SupabaseConfiguration.current {
            let dependencies = AppDependencies(configuration: configuration)
            self.repository = dependencies.repository
            self.sharedMomentRepository = dependencies.sharedMoments
            self.engagementTracker = dependencies.sharedMoments
            self.authService = dependencies.auth
            self.purchaseService = dependencies.purchases
            self.workspaceService = dependencies.workspace
        } else {
            self.repository = nil
            self.sharedMomentRepository = LocalSharedMomentRepository()
            self.engagementTracker = NoopEngagementTracker()
            self.authService = nil
            self.purchaseService = nil
            self.workspaceService = nil
            self.sessionState = .guest(userID: self.localParticipantID)
        }
        let calendar = Calendar.current
        let reveal = calendar.date(byAdding: .day, value: 5, to: .now) ?? .now
        let seedMissions = [
            Mission(title: "Leave a kind note", detail: "A few kind words.", category: .encouragement, minutes: 5, effort: "Easy", evidence: [.reflection]),
            Mission(title: "Clean a shared space", detail: "Care for a shared place.", category: .community, minutes: 20, effort: "Hands-on", evidence: [.photo]),
            Mission(title: "Donate a useful item", detail: "Pass something along.", category: .giving, minutes: 15, effort: "Easy", evidence: [.receipt]),
            Mission(title: "Check in with someone", detail: "Make room to listen.", category: .connection, minutes: 10, effort: "Quiet", evidence: [.organizer])
        ]
        let emotions = Emotion.allCases
        let methods = EvidenceMethod.allCases.filter { $0 != .partner }
        let names = ["Maya", "Jon", "Sam", "Noor"]
        var seed: [TileContribution] = []
        for index in 0..<18 {
            let contributor: String? = index % 3 == 0 ? nil : names[index % names.count]
            let item = TileContribution(
                id: UUID(),
                mission: seedMissions[index % seedMissions.count],
                emotion: emotions[index % emotions.count],
                evidence: methods[index % methods.count],
                contributor: contributor,
                sharedMemory: index % 4 == 0,
                isRevived: index == 7 || index == 14,
                participantID: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", (index % 4) + 1)),
                createdAt: calendar.date(byAdding: .hour, value: index, to: calendar.date(byAdding: .day, value: -7, to: .now) ?? .now) ?? .now,
                memory: index % 4 == 0 ? ContributionMemory(
                    kind: .reflection,
                    note: [
                        "A small note changed the tone of the whole afternoon.",
                        "We left the shared garden brighter than we found it.",
                        "Passing something useful along felt quietly hopeful.",
                        "Making time to listen mattered more than advice."
                    ][index % 4],
                    recapConsent: true,
                    attributionAllowed: contributor != nil
                ) : nil
            )
            seed.append(item)
        }
        challenge = KindnessChallenge(
            name: "A Kinder Block", purpose: "100 small acts to make our neighborhood feel closer.",
            goal: 40, revealDate: reveal, invitationCode: "KIND42", contributions: seed
        )
        let upcoming = KindnessChallenge(
            id: UUID(uuidString: "20000000-0000-4000-8000-000000000001")!,
            name: "Neighbors in Bloom",
            groupName: "West Ridge Neighbors",
            purpose: "Small acts that help our block feel ready for spring.",
            goal: 30,
            startDate: calendar.date(byAdding: .day, value: 10, to: .now) ?? .now,
            revealDate: calendar.date(byAdding: .day, value: 17, to: .now) ?? .now,
            invitationCode: "BLOOM7",
            contributions: Array(seed.prefix(4))
        )
        let completedReveal = calendar.date(byAdding: .day, value: -20, to: .now) ?? .now
        let completed = KindnessChallenge(
            id: UUID(uuidString: "20000000-0000-4000-8000-000000000002")!,
            name: "Warm Winter Table",
            groupName: "Mosaic Community",
            purpose: "Share practical care through the coldest week.",
            goal: 24,
            startDate: calendar.date(byAdding: .day, value: -28, to: .now) ?? .now,
            revealDate: completedReveal,
            revealedAt: completedReveal,
            serverStatus: "revealed",
            recapAvailability: .ready,
            invitationCode: "WARM24",
            contributions: Array(seed.prefix(16))
        )
        localChallenges = [
            challenge.id: challenge,
            upcoming.id: upcoming,
            completed.id: completed
        ]
        let cached = MosaicEventCache.loadSummaries()
        challengeLibrary = cached.isEmpty
            ? localChallenges.values.map(\.summary).sorted { $0.revealAt < $1.revealAt }
            : cached
        persistEventCache()

#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-preview-joined") {
            hasJoined = true
            displayName = "Biswas"
            privacyMode = "First name"
        }
#endif
    }

    func join(name: String, privacy: String) {
        displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        privacyMode = privacy
        hasJoined = true
        Task { await joinRemote() }
    }

    func addContribution(_ contribution: TileContribution) {
        let shouldOfferRecovery = pendingContribution == nil && !sessionState.isAuthenticated
        if !challenge.contributions.contains(where: { $0.id == contribution.id }) {
            challenge.contributions.append(contribution)
        }
        localChallenges[challenge.id] = challenge
        updateCurrentChallengeInLibrary()
        pendingContribution = contribution
        if shouldOfferRecovery { isShowingRecoveryPrompt = true }
        Task { await placeRemote(contribution) }
    }

    func openSharedCamera() {
        guard challenge.cameraRollEnabled else { return }
        showSharedCamera = true
        Task { await engagementTracker.track(.cameraOpen, challengeID: challenge.id) }
    }

    func openRecapEditor() {
        showRecapEditor = true
        Task { await engagementTracker.track(.recapOpen, challengeID: challenge.id) }
    }

    func keepPrivateSharedMoment(jpegData: Data, note: String = "") async {
        let candidate = SharedMoment(
            challengeID: challenge.id, creatorID: localParticipantID,
            note: note, revealConsent: false, exportConsent: false,
            lifecycle: .localDraft
        )
        guard let draft = try? await sharedMomentRepository.saveDraft(candidate, jpegData: jpegData) else { return }
        challenge.sharedMoments.append(draft)
        localChallenges[challenge.id] = challenge
    }

    func monitorPendingMomentUploads() async {
        for await connected in NetworkConnectivity.updates() where connected {
            await retryPendingMomentUploads()
        }
    }

    func retryPendingMomentUploads() async {
        let queued = challenge.sharedMoments.filter { $0.lifecycle == .uploadPending }
        for moment in queued {
            guard let name = moment.localAssetName,
                  let data = try? await ProtectedSharedMomentStore.shared.data(for: name),
                  let saved = try? await sharedMomentRepository.seal(moment, jpegData: data),
                  let index = challenge.sharedMoments.firstIndex(where: { $0.id == saved.id }) else { continue }
            challenge.sharedMoments[index] = saved
        }
    }

    func sealPrivateDraft(_ momentID: UUID) async {
        guard let moment = challenge.sharedMoments.first(where: { $0.id == momentID }),
              let name = moment.localAssetName,
              let data = try? await ProtectedSharedMomentStore.shared.data(for: name),
              let saved = try? await sharedMomentRepository.seal(moment, jpegData: data),
              let index = challenge.sharedMoments.firstIndex(where: { $0.id == momentID }) else { return }
        challenge.sharedMoments[index] = saved
        lastSealedMomentAt = .now
    }

    func revokeSharedMoment(_ momentID: UUID) async {
        guard let updated = try? await sharedMomentRepository.updateConsent(momentID: momentID, reveal: false, export: false),
              let index = challenge.sharedMoments.firstIndex(where: { $0.id == momentID }) else { return }
        challenge.sharedMoments[index] = updated
    }

    func deleteSharedMoment(_ momentID: UUID) async {
        try? await sharedMomentRepository.delete(momentID: momentID)
        challenge.sharedMoments.removeAll { $0.id == momentID }
    }

    @discardableResult
    func sealSharedMoment(
        jpegData: Data,
        note: String,
        category: MissionCategory?,
        exportConsent: Bool,
        attribution: SharedMomentAttribution
    ) async -> SharedMoment? {
        let moment = SharedMoment(
            challengeID: challenge.id,
            creatorID: localParticipantID,
            editorialCategory: category,
            note: note,
            attribution: attribution,
            revealConsent: true,
            exportConsent: exportConsent,
            lifecycle: .uploadPending
        )
        do {
            let saved = try await sharedMomentRepository.seal(moment, jpegData: jpegData)
            if !challenge.sharedMoments.contains(where: { $0.id == saved.id }) {
                challenge.sharedMoments.append(saved)
            }
            localChallenges[challenge.id] = challenge
            lastSealedMomentAt = .now
            await engagementTracker.track(.sealed, challengeID: challenge.id)
            return saved
        } catch {
            backendMessage = "Your moment is still private on this device. Please try sealing it again."
            return nil
        }
    }

    func bootstrap() async {
        if let authService {
            do {
                sessionState = try await authService.restoreOrCreateGuest()
                if let userID = sessionState.userID {
                    try? await purchaseService?.configure(customerID: userID)
                }
            } catch {
                sessionState = .failed(message: error.localizedDescription)
                accountMessage = error.localizedDescription
            }
        }
        guard let repository else {
            challenge.sharedMoments = (try? await sharedMomentRepository.moments(challengeID: challenge.id)) ?? []
            return
        }
        backendState = .connecting
        do {
            let result = try await repository.bootstrap(
                displayName: displayName.isEmpty ? nil : displayName,
                privacy: Self.databasePrivacy(privacyMode)
            )
            showcaseChallengeID = result.showcase.id
            sandboxChallengeID = result.sandbox?.id
            try await loadChallenge(result.showcase.id, organizer: false)
            await refreshLibrary()
            await refreshOrganizations()
            backendState = .live
            backendMessage = nil
        } catch {
            backendState = .cached(message: "Using the built-in showcase. Start the local Supabase stack to enable live collaboration.")
            backendMessage = error.localizedDescription
        }
    }

    func completeAppleAuthorization(_ authorization: AppleAuthorization, createWorkspace: Bool) async {
        guard let authService else { return }
        do {
            sessionState = try await authService.signInOrLinkWithApple(authorization)
            if let userID = sessionState.userID { try await purchaseService?.configure(customerID: userID) }
            await refreshOrganizations()
            if createWorkspace && organizations.isEmpty { isShowingOrganizerSetup = true }
            accountMessage = nil
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    func createOrganization(name: String, organizerName: String) async -> Bool {
        guard sessionState.isAuthenticated, let workspaceService else { return false }
        do {
            let (organization, challengeRecord) = try await workspaceService.createOrganization(
                name: name, organizerDisplayName: organizerName
            )
            organizations.append(organization)
            selectedOrganizationID = organization.id
            sandboxChallengeID = challengeRecord.id
            try await loadChallenge(challengeRecord.id, organizer: true)
            accessSnapshot = try await workspaceService.accessSnapshot(organizationID: organization.id, challengeID: challengeRecord.id)
            isShowingOrganizerSetup = false
            hasJoined = true
            accountMessage = nil
            return true
        } catch {
            accountMessage = error.localizedDescription
            return false
        }
    }

    func refreshOrganizations() async {
        guard sessionState.isAuthenticated, let workspaceService else {
            organizations = []
            selectedOrganizationID = nil
            accessSnapshot = .free
            return
        }
        do {
            organizations = try await workspaceService.organizations()
            if !organizations.contains(where: { $0.id == selectedOrganizationID }) {
                selectedOrganizationID = organizations.first?.id
            }
            if let selectedOrganizationID {
                accessSnapshot = try await workspaceService.accessSnapshot(organizationID: selectedOrganizationID, challengeID: challenge.id)
            }
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    func selectOrganization(_ organizationID: UUID) async {
        guard organizations.contains(where: { $0.id == organizationID }) else { return }
        selectedOrganizationID = organizationID
        if let workspaceService {
            accessSnapshot = (try? await workspaceService.accessSnapshot(organizationID: organizationID, challengeID: challenge.id)) ?? .free
        }
    }

    func requestPremium(_ feature: PremiumFeature) {
        guard !accessSnapshot.allows(feature) else { return }
        paywallContext = feature
        isShowingPaywall = true
    }

    func refreshBilling() async {
        guard let purchaseService else { return }
        do {
            accessSnapshot = try await purchaseService.refreshAccess(
                organizationID: selectedOrganizationID,
                challengeID: challenge.id
            )
            accountMessage = nil
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard let purchaseService else { return }
        do {
            accessSnapshot = try await purchaseService.restore(
                organizationID: selectedOrganizationID,
                challengeID: challenge.id
            )
            accountMessage = "Purchases restored."
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    func redeemEventPass() async {
        guard let purchaseService, let selectedOrganizationID else { return }
        do {
            accessSnapshot = try await purchaseService.redeemEventPass(
                organizationID: selectedOrganizationID, challengeID: challenge.id
            )
            accountMessage = "Mosaic Pass applied to this challenge."
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    func createCollaboratorInvite(role: OrganizationRole) async {
        guard let workspaceService, let selectedOrganizationID else { return }
        do {
            latestCollaboratorInvite = try await workspaceService.createInvite(
                organizationID: selectedOrganizationID, role: role
            )
            accountMessage = "A single-use \(role.rawValue) link is ready. It expires in seven days."
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    func acceptWorkspaceInvite(token: String) async {
        guard sessionState.isAuthenticated, let workspaceService else { return }
        do {
            let organization = try await workspaceService.acceptInvite(token: token)
            await refreshOrganizations()
            selectedOrganizationID = organization.id
            accountMessage = "You joined \(organization.name) as \(organization.role.rawValue)."
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    var selectedOrganization: OrganizationSummary? {
        organizations.first { $0.id == selectedOrganizationID }
    }

    func signOut() async {
        guard let authService else { return }
        do {
            sessionState = try await authService.signOutToFreshGuest()
            if let userID = sessionState.userID { try? await purchaseService?.configure(customerID: userID) }
            organizations = []
            selectedOrganizationID = nil
            accessSnapshot = .free
            isOrganizer = false
            await bootstrap()
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    func deleteAccount() async {
        guard let authService else { return }
        do {
            sessionState = try await authService.deleteAccount()
            if let userID = sessionState.userID { try? await purchaseService?.configure(customerID: userID) }
            organizations = []
            selectedOrganizationID = nil
            accessSnapshot = .free
            isOrganizer = false
            await bootstrap()
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    func deleteSelectedOrganization() async {
        guard let workspaceService, let selectedOrganizationID else { return }
        do {
            try await workspaceService.deleteOrganization(organizationID: selectedOrganizationID)
            await refreshOrganizations()
            accountMessage = "Workspace deleted. Apple subscriptions must still be managed separately."
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    func transferSelectedOrganization(to userID: UUID) async {
        guard let workspaceService, let selectedOrganizationID else { return }
        do {
            try await workspaceService.transferOwnership(organizationID: selectedOrganizationID, newOwnerID: userID)
            await refreshOrganizations()
            accountMessage = "Ownership transferred. App Store subscriptions do not transfer."
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    func openOrganizerSandbox() async {
        guard let sandboxChallengeID else {
            await bootstrap()
            if let sandboxChallengeID { try? await loadChallenge(sandboxChallengeID, organizer: true) }
            return
        }
        try? await loadChallenge(sandboxChallengeID, organizer: true)
    }

    @discardableResult
    func configureChallenge(_ draft: ChallengeDraft) async -> KindnessChallenge? {
        guard draft.isReadyToCreate else {
            backendMessage = "Complete the block details before creating it."
            return nil
        }

        guard let repository else {
            let local = KindnessChallenge(
                name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                groupName: draft.groupName.trimmingCharacters(in: .whitespacesAndNewlines),
                purpose: draft.purpose.trimmingCharacters(in: .whitespacesAndNewlines),
                goal: draft.goal,
                startDate: draft.startDate,
                revealDate: draft.revealDate,
                invitationCode: Self.localInvitationCode(for: draft.name),
                contributions: [],
                theme: draft.selection
            )
            challenge = local
            isOrganizer = true
            localChallenges[local.id] = local
            updateCurrentChallengeInLibrary()
            return local
        }

        if sandboxChallengeID == nil { await bootstrap() }
        guard let challengeID = sandboxChallengeID else {
            backendMessage = "An organizer space could not be prepared."
            return nil
        }

        do {
            _ = try await repository.configureChallenge(draft, challengeID: challengeID)
            try await loadChallenge(challengeID, organizer: true)
            await refreshLibrary()
            backendMessage = nil
            return challenge
        } catch {
            backendMessage = error.localizedDescription
            return nil
        }
    }

    func returnToShowcase() async {
        guard let showcaseChallengeID else { return }
        try? await loadChallenge(showcaseChallengeID, organizer: false)
    }

    @discardableResult
    func submitContribution(
        _ contribution: TileContribution,
        reflection: String,
        mediaData: Data?,
        mimeType: String?,
        durationSeconds: Double?,
        includeMemory: Bool,
        showIdentity: Bool,
        exportConsent: Bool
    ) async -> Bool {
        let shouldOfferRecovery = pendingContribution == nil && !sessionState.isAuthenticated
        pendingContribution = contribution
        guard let repository else { return true }
        do {
            let record = try await repository.submit(EvidenceDraft(
                id: contribution.id,
                challengeID: challenge.id,
                missionID: contribution.mission.id,
                emotion: contribution.emotion,
                method: contribution.evidence,
                reflection: reflection.isEmpty ? nil : reflection,
                mediaData: mediaData,
                mimeType: mimeType,
                durationSeconds: durationSeconds,
                includeMemory: includeMemory,
                showIdentity: showIdentity,
                exportConsent: exportConsent
            ))
            pendingContribution = contribution.updated(status: record.status, tilePosition: record.tilePosition)
            if shouldOfferRecovery { isShowingRecoveryPrompt = true }
            await refresh()
            return true
        } catch {
            backendState = .failed(message: "Evidence was kept as a retryable draft.")
            backendMessage = error.localizedDescription
            return false
        }
    }

    func moderate(_ contributionID: UUID, approved: Bool, approveMemory: Bool? = nil) async {
        guard let repository else { return }
        do {
            _ = try await repository.moderate(
                contributionID: contributionID,
                evidenceApproved: approved,
                memoryApproved: approveMemory
            )
            await refresh()
        } catch {
            backendMessage = error.localizedDescription
        }
    }

    func moderateSharedMoment(_ momentID: UUID, approved: Bool) async {
        do {
            let updated = try await sharedMomentRepository.moderate(momentID: momentID, approved: approved)
            if let index = challenge.sharedMoments.firstIndex(where: { $0.id == momentID }) {
                challenge.sharedMoments[index] = updated
            }
        } catch {
            backendMessage = error.localizedDescription
        }
    }

    func startReveal() async {
        guard let repository else {
            challenge.revealedAt = .now
            challenge.serverStatus = "revealed"
            challenge.recapAvailability = .processing
            updateCurrentChallengeInLibrary()
            showReveal = true
            return
        }
        do {
            _ = try await repository.reveal(challengeID: challenge.id, now: true, at: nil)
            showReveal = true
            await refresh()
        } catch {
            backendMessage = error.localizedDescription
        }
    }

    func refresh() async {
        guard repository != nil else { return }
        try? await loadChallenge(challenge.id, organizer: isOrganizer)
        await refreshLibrary()
    }

    var nextChallenge: ChallengeSummary? {
        MosaicEventCache.automaticSummary(from: challengeLibrary)
    }

    func summary(for id: UUID) -> ChallengeSummary? {
        challengeLibrary.first { $0.id == id }
    }

    func preferences(for challengeID: UUID) -> NotificationPreferences {
        notificationPreferences[challengeID] ?? .helpful
    }

    func openChallenge(_ id: UUID) async {
        if challenge.id == id { return }
        if repository != nil {
            do {
                try await loadChallenge(id, organizer: false)
                return
            } catch {
                backendMessage = error.localizedDescription
            }
        }
        if let local = localChallenges[id] {
            challenge = local
            isOrganizer = false
            updateCurrentChallengeInLibrary()
        }
    }

    @discardableResult
    func saveNotificationPreferences(
        _ preferences: NotificationPreferences,
        for summary: ChallengeSummary
    ) async -> NotificationPermissionState {
        notificationPreferences[summary.id] = preferences
        MosaicEventCache.savePreferences(notificationPreferences)
        do {
            try await repository?.updateNotificationPreferences(
                challengeID: summary.id,
                preferences: preferences
            )
            if !preferences.liveActivity {
                await MosaicLiveActivityManager.shared.stop(challengeID: summary.id)
            }
            guard preferences.remindersEnabled else {
                await EventNotificationManager.shared.removePending(for: summary.id)
                if preferences.liveActivity { _ = try? await followLive(summary) }
                return await EventNotificationManager.shared.permissionState()
            }
            let state = try await EventNotificationManager.shared.requestPermissionAndSchedule(
                summary: summary,
                preferences: preferences
            )
            if state == .allowed, preferences.liveActivity {
                _ = try? await followLive(summary)
            }
            return state
        } catch {
            backendMessage = error.localizedDescription
            return await EventNotificationManager.shared.permissionState()
        }
    }

    func followLive(_ summary: ChallengeSummary) async throws -> LiveFollowResult {
        var updated = preferences(for: summary.id)
        updated.liveActivity = true
        notificationPreferences[summary.id] = updated
        MosaicEventCache.savePreferences(notificationPreferences)
        try await repository?.updateNotificationPreferences(
            challengeID: summary.id,
            preferences: updated
        )
        if await EventNotificationManager.shared.permissionState() == .allowed {
            try await EventNotificationManager.shared.schedule(summary: summary, preferences: updated)
        }
        return try await MosaicLiveActivityManager.shared.follow(summary: summary) { [weak self] token, challengeID, activityID in
            await self?.registerLiveActivityToken(token, challengeID: challengeID, activityID: activityID)
        }
    }

    private func registerLiveActivityToken(_ token: String, challengeID: UUID, activityID: String) async {
        try? await repository?.registerLiveActivityToken(
            token: token, challengeID: challengeID, activityID: activityID
        )
    }

    func keepOnWidget(_ summary: ChallengeSummary) {
        MosaicEventCache.preferredWidgetChallengeID = summary.id
        WidgetCenter.shared.reloadAllTimelines()
    }

    @discardableResult
    func scheduleReveal(at date: Date) async -> Bool {
        guard date > .now else { return false }
        let oldDate = challenge.revealDate
        do {
            if let repository {
                _ = try await repository.reveal(challengeID: challenge.id, now: false, at: date)
                await refresh()
            } else {
                challenge.revealDate = date
                challenge.scheduleRevision += 1
                localChallenges[challenge.id] = challenge
                updateCurrentChallengeInLibrary()
            }
            if oldDate != date {
                calendarUpdateRequired.insert(challenge.id)
                if let summary = summary(for: challenge.id),
                   let preferences = notificationPreferences[challenge.id] {
                    try? await EventNotificationManager.shared.schedule(
                        summary: summary,
                        preferences: preferences
                    )
                }
            }
            return true
        } catch {
            backendMessage = error.localizedDescription
            return false
        }
    }

    func handle(url: URL) {
        if url.scheme == "mosaic", url.host == "workspace-invite" {
            let token = url.pathComponents.last(where: { $0 != "/" })
            pendingWorkspaceInviteToken = token
            if sessionState.isAuthenticated, let token {
                Task { await acceptWorkspaceInvite(token: token) }
            } else {
                isShowingInviteAcceptance = true
            }
            return
        }
        guard let route = EventRouteParser.parse(url) else { return }
        pendingRoute = route
    }

    func consumePendingRoute() -> EventRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    func registerDeviceToken(_ token: String) async {
#if DEBUG
        let environment = "sandbox"
#else
        let environment = "production"
#endif
        try? await repository?.registerDevice(token: token, environment: environment)
    }

    func refreshLibrary() async {
        guard let repository else {
            updateCurrentChallengeInLibrary()
            return
        }
        do {
            let previous = Dictionary(uniqueKeysWithValues: challengeLibrary.map { ($0.id, $0) })
            let loaded = try await repository.listChallenges()
            if !loaded.isEmpty {
                challengeLibrary = loaded
                for summary in loaded {
                    guard let old = previous[summary.id],
                          old.scheduleRevision != summary.scheduleRevision || old.revealAt != summary.revealAt
                    else { continue }
                    calendarUpdateRequired.insert(summary.id)
                    if let preferences = notificationPreferences[summary.id] {
                        try? await EventNotificationManager.shared.schedule(
                            summary: summary,
                            preferences: preferences
                        )
                    }
                }
                persistEventCache()
                await MosaicLiveActivityManager.shared.updateActivities(using: loaded)
                let visibleIDs = Set(
                    loaded.filter { $0.phase() != .completed }.prefix(8).map(\.id)
                ).union([challenge.id])
                for id in visibleIDs { startRealtime(for: id) }
                let staleIDs = realtimeTasks.keys.filter { !visibleIDs.contains($0) }
                for id in staleIDs {
                    realtimeTasks.removeValue(forKey: id)?.cancel()
                }
            }
        } catch {
            backendMessage = error.localizedDescription
        }
    }

    private func joinRemote() async {
        guard let repository else { return }
        do {
            _ = try await repository.join(
                code: challenge.invitationCode,
                displayName: displayName,
                privacy: Self.databasePrivacy(privacyMode)
            )
            await bootstrap()
        } catch {
            backendMessage = error.localizedDescription
        }
    }

    private func loadChallenge(_ id: UUID, organizer: Bool) async throws {
        guard let repository else { return }
        let localOnly = challenge.id == id
            ? challenge.sharedMoments.filter { $0.lifecycle == .localDraft || $0.lifecycle == .uploadPending }
            : []
        var loaded = try await repository.loadChallenge(id: id)
        let remoteMoments = (try? await sharedMomentRepository.moments(challengeID: id)) ?? []
        loaded.0.sharedMoments = remoteMoments + localOnly.filter { local in !remoteMoments.contains(where: { $0.id == local.id }) }
        applyLoadedChallenge(loaded, organizer: organizer)
        updateCurrentChallengeInLibrary()
        startRealtime(for: id)
    }

    private func applyLoadedChallenge(
        _ loaded: (KindnessChallenge, [Mission]),
        organizer: Bool
    ) {
        challenge = loaded.0
        missions = loaded.1
        isOrganizer = organizer
        if let pendingContribution,
           let refreshed = challenge.contributions.first(where: { $0.id == pendingContribution.id }) {
            self.pendingContribution = refreshed
        }
    }

    private func startRealtime(for id: UUID) {
        guard let repository else { return }
        guard realtimeTasks[id] == nil else { return }
        realtimeTasks[id] = Task { [weak self, repository] in
            guard let stream = try? await repository.changes(for: id) else {
                self?.realtimeTasks[id] = nil
                return
            }
            for await _ in stream {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                if self.challenge.id == id {
                    await self.refresh()
                } else {
                    await self.refreshLibrary()
                }
            }
            self?.realtimeTasks[id] = nil
        }
    }

    private func updateCurrentChallengeInLibrary() {
        let summary = challenge.summary
        if let index = challengeLibrary.firstIndex(where: { $0.id == summary.id }) {
            challengeLibrary[index] = summary
        } else {
            challengeLibrary.append(summary)
        }
        challengeLibrary.sort { $0.revealAt < $1.revealAt }
        persistEventCache()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func persistEventCache() {
        MosaicEventCache.saveSummaries(challengeLibrary)
    }

    private func placeRemote(_ contribution: TileContribution) async {
        guard let repository, backendState.isLive else { return }
        do {
            _ = try await repository.place(contributionID: contribution.id)
            await refresh()
        } catch {
            backendMessage = error.localizedDescription
        }
    }

    private static func databasePrivacy(_ value: String) -> String {
        switch value {
        case "Anonymous": "anonymous"
        case "Quiet participant": "quiet"
        default: "first_name"
        }
    }

    private static func persistedParticipantID() -> UUID {
        let key = "mosaic.local-participant-id"
        if let value = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: value) { return id }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }

    private static func localInvitationCode(for name: String) -> String {
        let letters = name.uppercased().filter(\.isLetter).prefix(4)
        let number = abs(name.hashValue % 9_000) + 1_000
        return "\(letters.isEmpty ? "KIND" : String(letters))\(number)"
    }
}

private extension TileContribution {
    func updated(status: ContributionStatus, tilePosition: Int?) -> TileContribution {
        TileContribution(
            id: id,
            mission: mission,
            emotion: emotion,
            evidence: evidence,
            contributor: contributor,
            sharedMemory: sharedMemory,
            isRevived: isRevived,
            status: status,
            tilePosition: tilePosition,
            participantID: participantID,
            createdAt: createdAt,
            memory: memory,
            isDeleted: isDeleted,
            isReported: isReported,
            contributorIsBlocked: contributorIsBlocked
        )
    }
}
