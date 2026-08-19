import Foundation
import Observation

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
    @ObservationIgnored private var realtimeTask: Task<Void, Never>?

    init(repository: MosaicRepository? = nil) {
        if let repository {
            self.repository = repository
        } else if NSClassFromString("XCTestCase") == nil, let configuration = SupabaseConfiguration.current {
            self.repository = SupabaseMosaicRepository(configuration: configuration)
        } else {
            self.repository = nil
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
                isRevived: index == 7 || index == 14
            )
            seed.append(item)
        }
        challenge = KindnessChallenge(
            name: "A Kinder Block", purpose: "100 small acts to make our neighborhood feel closer.",
            goal: 40, revealDate: reveal, invitationCode: "KIND42", contributions: seed
        )

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
        if !challenge.contributions.contains(where: { $0.id == contribution.id }) {
            challenge.contributions.append(contribution)
        }
        pendingContribution = contribution
        Task { await placeRemote(contribution) }
    }

    func bootstrap() async {
        guard let repository else { return }
        backendState = .connecting
        do {
            let result = try await repository.bootstrap(
                displayName: displayName.isEmpty ? nil : displayName,
                privacy: Self.databasePrivacy(privacyMode)
            )
            showcaseChallengeID = result.showcase.id
            sandboxChallengeID = result.sandbox.id
            try await loadChallenge(result.showcase.id, organizer: false)
            backendState = .live
            backendMessage = nil
        } catch {
            backendState = .cached(message: "Using the built-in showcase. Start the local Supabase stack to enable live collaboration.")
            backendMessage = error.localizedDescription
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

    func startReveal() async {
        guard let repository else {
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
        let loaded = try await repository.loadChallenge(id: id)
        challenge = loaded.0
        missions = loaded.1
        isOrganizer = organizer
        if let pendingContribution,
           let refreshed = challenge.contributions.first(where: { $0.id == pendingContribution.id }) {
            self.pendingContribution = refreshed
        }
        realtimeTask?.cancel()
        realtimeTask = Task { [weak self, repository] in
            guard let stream = try? await repository.changes(for: id) else { return }
            for await _ in stream {
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
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
            tilePosition: tilePosition
        )
    }
}
