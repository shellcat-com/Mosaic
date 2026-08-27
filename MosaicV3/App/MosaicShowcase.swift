#if DEBUG
import Foundation
import SwiftUI
import UIKit

enum MosaicShowcaseScreen: String {
    case root
    case signIn
    case displayName
    case home
    case create
    case join
    case activity
    case active
    case revealed
    case reveal100
    case reveal100ReducedMotion
    case photos
    case recap
    case recapJourney
    case camera
    case cameraReview
    case cameraDenied
    case you
    case paywallLoading
    case paywallPopulated
    case paywallFailure
    case paywallPlusActive
    case paywallPassOwned
    case paywallPurchaseSuccess
    case paywallRestoreSuccess
}

enum MosaicShowcaseFixtures {
    static let memberID = UUID(uuidString: "71000000-0000-4000-8000-000000000001")!
    static let activeID = UUID(uuidString: "72000000-0000-4000-8000-000000000001")!
    static let revealedID = UUID(uuidString: "72000000-0000-4000-8000-000000000002")!
    static let performanceID = UUID(uuidString: "72000000-0000-4000-8000-000000000100")!

    @MainActor static func makeModel(screen: MosaicShowcaseScreen? = nil) -> MosaicAppModel {
        var events = makeEvents()
        if screen == .reveal100 || screen == .reveal100ReducedMotion { events.append(makeHundredTileEvent()) }
        let api = ShowcaseMosaicAPI(events: events)
        return MosaicAppModel(
            showcaseAPI: api,
            profile: MosaicProfile(id: memberID, displayName: "Maya", createdAt: .now)
        )
    }

    static func makeEvents() -> [MosaicEvent] {
        let activeActivities = activities(mosaicID: activeID)
        var activeContributions: [KindnessContribution] = []
        for index in 0..<7 {
            let note: String? = index < 2
                ? ["I brought extra seedlings for a neighbor.", "We cleared litter beside the garden path."][index]
                : nil
            activeContributions.append(contribution(
                id: index,
                mosaicID: activeID,
                activityID: activeActivities[index % activeActivities.count].id,
                tile: index,
                name: index < 2 ? "Maya" : nil,
                note: note,
                isMine: index < 2
            ))
        }
        let active = MosaicEvent(
            id: activeID,
            name: "Willow Street Garden Day",
            communityName: "Willow Street Neighbors",
            description: "Small acts that help our shared garden feel cared for.",
            creatorID: memberID,
            invitationCode: "GARDEN24",
            invitationURL: URL(string: "mosaic://join/GARDEN24")!,
            startAt: .now.addingTimeInterval(-3_600),
            revealAt: .now.addingTimeInterval(60.0 * 60.0 * 18.0),
            goal: 25,
            filmLookID: .garden,
            shotLimit: 24,
            artwork: CuratedArtwork.collection[0],
            activities: activeActivities,
            contributions: activeContributions.filter { $0.isMine },
            contributionCount: 7,
            occupiedTilePositions: Array(0..<7),
            photos: [],
            memberCount: 18,
            isCreator: true
        )

        let revealedActivities = activities(mosaicID: revealedID)
        let names = ["Maya", "Noah", "Avery", "Sam"]
        let notes = [
            "Made room for someone new at lunch.",
            "Carried groceries upstairs for a neighbor.",
            "Left the reading corner better than I found it.",
            "Checked in on a friend who had a hard week."
        ]
        var revealedContributions: [KindnessContribution] = []
        for index in 0..<11 {
            revealedContributions.append(contribution(
                id: 20 + index,
                mosaicID: revealedID,
                activityID: revealedActivities[index % revealedActivities.count].id,
                tile: index,
                name: names[index % names.count],
                note: notes[index % notes.count],
                isMine: index % 4 == 0
            ))
        }
        let revealed = MosaicEvent(
            id: revealedID,
            name: "A Week of Small Kindness",
            communityName: "Northstar School",
            description: "One week of noticing where a small gesture could help.",
            creatorID: UUID(),
            invitationCode: "NORTHSTAR",
            invitationURL: URL(string: "mosaic://join/NORTHSTAR")!,
            startAt: .now.addingTimeInterval(-60 * 60 * 24 * 8),
            revealAt: .now.addingTimeInterval(-60 * 60),
            goal: 16,
            filmLookID: .afterglow,
            shotLimit: 12,
            artwork: CuratedArtwork.collection[2],
            activities: revealedActivities,
            contributions: revealedContributions,
            contributionCount: 11,
            occupiedTilePositions: Array(0..<11),
            photos: photos(mosaicID: revealedID),
            memberCount: 26,
            isCreator: false
        )
        return [active, revealed]
    }

    static func makeRecapProject() -> PhotoRecapProject {
        let event = makeEvents().first { $0.id == revealedID }!
        var selection = PhotoRecapSelection()
        for photo in event.photos.prefix(4) { selection.toggle(photo.id) }
        return PhotoRecapProject(
            mosaicID: revealedID,
            selection: selection,
            template: .kilnTape,
            music: .summer,
            musicTrimOffset: 3
        )
    }

    static func makeHundredTileEvent() -> MosaicEvent {
        let eventActivities = activities(mosaicID: performanceID)
        let eventContributions = (0..<73).map { index in
            contribution(
                id: 200 + index,
                mosaicID: performanceID,
                activityID: eventActivities[index % eventActivities.count].id,
                tile: index,
                name: "Member \(index + 1)",
                note: nil,
                isMine: index == 0
            )
        }
        return MosaicEvent(
            id: performanceID,
            name: "One Hundred Small Acts",
            communityName: "Mosaic Performance Fixture",
            description: "A maximum-size reveal fixture.",
            creatorID: memberID,
            invitationCode: "HUNDRED1",
            invitationURL: URL(string: "mosaic://join/HUNDRED1")!,
            startAt: .now.addingTimeInterval(-7_200),
            revealAt: .now.addingTimeInterval(-60),
            goal: 100,
            filmLookID: .sunwashed,
            shotLimit: 24,
            artwork: CuratedArtwork.collection[1],
            activities: eventActivities,
            contributions: eventContributions,
            contributionCount: eventContributions.count,
            occupiedTilePositions: eventContributions.map(\.tilePosition),
            photos: [],
            memberCount: 84,
            isCreator: true
        )
    }

    private static func activities(mosaicID: UUID) -> [KindnessActivity] {
        [
            ("Welcome someone new", "Help one person feel seen and included."),
            ("Care for a shared place", "Leave a common space gentler than you found it."),
            ("Offer practical help", "Notice a small burden you can make lighter."),
            ("Check in with someone", "Give your full attention to someone who may need it.")
        ].enumerated().map { index, value in
            KindnessActivity(
                id: UUID(uuidString: String(format: "73000000-0000-4000-8000-%012d", index + (mosaicID == activeID ? 1 : 101)))!,
                mosaicID: mosaicID,
                title: value.0,
                purpose: value.1,
                sortOrder: index,
                participantCompleted: index < 2
            )
        }
    }

    private static func contribution(id: Int, mosaicID: UUID, activityID: UUID, tile: Int, name: String?, note: String?, isMine: Bool) -> KindnessContribution {
        KindnessContribution(
            id: UUID(uuidString: String(format: "74000000-0000-4000-8000-%012d", id + 1))!,
            mosaicID: mosaicID,
            activityID: activityID,
            participantID: isMine ? memberID : UUID(),
            contributorDisplayName: name,
            tilePosition: tile,
            note: note,
            createdAt: .now.addingTimeInterval(Double(-id * 800)),
            updatedAt: .now,
            isMine: isMine
        )
    }

    private static func photos(mosaicID: UUID) -> [EventPhoto] {
        let assets = CuratedArtwork.collection.map(\.assetName) + ["OnboardingWaterLilies", "OnboardingParisStreet"]
        return assets.enumerated().map { index, asset in
            let id = UUID(uuidString: String(format: "75000000-0000-4000-8000-%012d", index + 1))!
            return EventPhoto(
                id: id,
                mosaicID: mosaicID,
                photographerID: index % 2 == 0 ? memberID : UUID(),
                photographerDisplayName: index % 2 == 0 ? "Maya" : "Noah",
                filmLookID: .afterglow,
                capturedAt: .now.addingTimeInterval(Double(-index * 1_200)),
                state: .eligible,
                storagePath: nil,
                localURL: localImageURL(asset: asset, id: id),
                signedURL: nil,
                pixelWidth: 900,
                pixelHeight: 1_200,
                isMine: index % 2 == 0
            )
        }
    }

    private static func localImageURL(asset: String, id: UUID) -> URL? {
        guard let data = UIImage(named: asset)?.jpegData(compressionQuality: 0.9) else { return nil }
        let directory = FileManager.default.temporaryDirectory.appending(path: "MosaicShowcase", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(id.uuidString).jpg")
        try? data.write(to: url, options: .atomic)
        return url
    }
}

actor ShowcaseMosaicAPI: MosaicAPI {
    private var events: [UUID: MosaicEvent]

    init(events: [MosaicEvent]) { self.events = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) }) }

    func listMosaics() async throws -> [MosaicSummary] { events.values.map(\.summary).sorted { $0.revealAt < $1.revealAt } }
    func createMosaic(_ draft: MosaicDraft) async throws -> MosaicEvent { try event(MosaicShowcaseFixtures.activeID) }
    func createPremiumMosaic(_ draft: MosaicDraft, requestID: UUID) async throws -> MosaicEvent { try event(MosaicShowcaseFixtures.activeID) }
    func billingSnapshot() async throws -> BillingSnapshot { .free }
    func refreshBilling() async throws -> BillingSnapshot { .free }
    func resolveInvitation(_ code: String) async throws -> MosaicInvitationPreview {
        let value = try event(MosaicShowcaseFixtures.activeID)
        return .init(code: value.invitationCode, name: value.name, communityName: value.communityName, description: value.description, revealAt: value.revealAt, artwork: value.artwork, memberCount: value.memberCount)
    }
    func joinMosaic(_ code: String) async throws -> MosaicEvent { try event(MosaicShowcaseFixtures.activeID) }
    func loadMosaic(_ id: UUID) async throws -> MosaicEvent { try event(id) }
    func updateMosaic(_ id: UUID, name: String, description: String) async throws -> MosaicEvent {
        guard var value = events[id] else { throw MosaicAPIError.invalidResponse }
        value.name = name; value.description = description; events[id] = value; return value
    }
    func deleteMosaic(_ id: UUID) async throws { events[id] = nil }
    func completeActivity(mosaicID: UUID, activityID: UUID, note: String?) async throws -> KindnessContribution {
        guard var value = events[mosaicID],
              let activityIndex = value.activities.firstIndex(where: { $0.id == activityID }),
              !value.activities[activityIndex].participantCompleted,
              value.contributionCount < value.goal else { throw MosaicAPIError.message("This activity is already complete or the board is full.") }
        let occupied = Set(value.occupiedTilePositions)
        guard let tile = (0..<value.goal).first(where: { !occupied.contains($0) }) else { throw MosaicAPIError.message("The board is full.") }
        let contribution = KindnessContribution(
            id: UUID(), mosaicID: mosaicID, activityID: activityID,
            participantID: MosaicShowcaseFixtures.memberID, contributorDisplayName: "Maya",
            tilePosition: tile, note: note, createdAt: .now, updatedAt: .now, isMine: true
        )
        value.activities[activityIndex].participantCompleted = true
        value.contributions.append(contribution)
        value.contributionCount += 1
        value.occupiedTilePositions.append(tile)
        events[mosaicID] = value
        return contribution
    }
    func updateContribution(_ id: UUID, note: String?) async throws -> KindnessContribution {
        for eventID in events.keys {
            guard var value = events[eventID], let index = value.contributions.firstIndex(where: { $0.id == id }) else { continue }
            value.contributions[index].note = note
            value.contributions[index].updatedAt = .now
            events[eventID] = value
            return value.contributions[index]
        }
        throw MosaicAPIError.invalidResponse
    }
    func withdrawContribution(_ id: UUID) async throws {
        for eventID in events.keys {
            guard var value = events[eventID], let removed = value.contributions.first(where: { $0.id == id }) else { continue }
            value.contributions.removeAll { $0.id == id }
            value.contributionCount = max(0, value.contributionCount - 1)
            value.occupiedTilePositions.removeAll { $0 == removed.tilePosition }
            if let activityIndex = value.activities.firstIndex(where: { $0.id == removed.activityID }) {
                value.activities[activityIndex].participantCompleted = false
            }
            events[eventID] = value
            return
        }
    }
    func preparePhoto(mosaicID: UUID, photoID: UUID, byteCount: Int, pixelWidth: Int, pixelHeight: Int) async throws -> PreparedPhotoUpload { throw MosaicAPIError.message("Showcase only") }
    func uploadPhoto(_ upload: PreparedPhotoUpload, jpeg: Data) async throws {}
    func finalizePhoto(_ photoID: UUID) async throws -> EventPhoto { throw MosaicAPIError.message("Showcase only") }
    func deletePhoto(_ photoID: UUID) async throws {}
    func reportPhoto(_ photoID: UUID, reason: String) async throws {}
    func blockUser(_ userID: UUID) async throws {}
    func unblockUser(_ userID: UUID) async throws {}
    func blockedUsers() async throws -> [BlockedUser] { [] }
    func releaseArtwork(_ mosaicID: UUID) async throws -> ArtworkRevealMaterial? { nil }

    private func event(_ id: UUID) throws -> MosaicEvent {
        guard let value = events[id] else { throw MosaicAPIError.invalidResponse }
        return value
    }
}

struct MosaicShowcaseRoot: View {
    let screen: MosaicShowcaseScreen
    @Environment(MosaicAppModel.self) private var model
    @State private var path: [MosaicRoute] = []

    var body: some View {
        Group {
            switch screen {
            case .root:
                EmptyView()
            case .signIn:
                SignInView(invitationCode: nil)
            case .displayName:
                DisplayNameView()
            case .home:
                NavigationStack { MosaicsHomeView(path: $path) }
                    .task { await model.library.refresh() }
            case .create:
                NavigationStack { CreateMosaicView(path: $path) }
            case .join:
                NavigationStack { JoinMosaicView(prefilledCode: "GARDEN24", path: $path) }
            case .activity:
                NavigationStack { KindnessActivityView(activityID: MosaicShowcaseFixtures.makeEvents()[0].activities[2].id) }
                    .task { await model.detail.load(id: MosaicShowcaseFixtures.activeID) }
            case .active:
                NavigationStack { MosaicEventView(eventID: MosaicShowcaseFixtures.activeID, path: $path) }
            case .revealed:
                NavigationStack { MosaicEventView(eventID: MosaicShowcaseFixtures.revealedID, path: $path) }
            case .reveal100:
                NavigationStack { MosaicEventView(eventID: MosaicShowcaseFixtures.performanceID, path: $path) }
            case .reveal100ReducedMotion:
                NavigationStack {
                    MosaicReducedMotionRevealShowcase()
                }
            case .photos:
                NavigationStack { MosaicEventView(eventID: MosaicShowcaseFixtures.revealedID, path: $path) }
                    .task { model.detail.selectedOutcome = .photos }
            case .recap:
                NavigationStack {
                    PhotoRecapBuilderView(
                        eventID: MosaicShowcaseFixtures.revealedID,
                        initialProject: MosaicShowcaseFixtures.makeRecapProject(),
                        initialStage: .style
                    )
                }
                    .task { await model.detail.load(id: MosaicShowcaseFixtures.revealedID) }
            case .recapJourney:
                NavigationStack {
                    PhotoRecapBuilderView(eventID: MosaicShowcaseFixtures.revealedID)
                }
                .task { await model.detail.load(id: MosaicShowcaseFixtures.revealedID) }
            case .camera:
                MosaicShowcaseCamera()
            case .cameraReview:
                MosaicShowcaseCameraReview()
            case .cameraDenied:
                MosaicShowcaseCameraDenied()
            case .you:
                NavigationStack { YouView(path: $path) }
            case .paywallLoading:
                MosaicPaywallView().task { model.billing.setShowcase(snapshot: .free, loadState: .loading) }
            case .paywallPopulated:
                MosaicPaywallView().task { model.billing.setShowcase(snapshot: .free) }
            case .paywallFailure:
                MosaicPaywallView().task {
                    model.billing.setShowcase(snapshot: .free, loadState: .failed("The Test Store offering could not be reached."))
                }
            case .paywallPlusActive:
                MosaicPaywallView().task { model.billing.setShowcase(snapshot: .showcasePlus) }
            case .paywallPassOwned:
                MosaicPaywallView().task { model.billing.setShowcase(snapshot: .showcasePass) }
            case .paywallPurchaseSuccess, .paywallRestoreSuccess:
                MosaicPaywallView().task { model.billing.setShowcase(snapshot: .showcasePlus, actionState: .success) }
            }
        }
        .tint(MosaicTheme.accentForeground)
    }
}

private extension BillingSnapshot {
    static let showcasePlus = BillingSnapshot(
        plusActive: true, subscriptionState: .active,
        productID: MosaicBillingCatalog.annualProductID,
        expiresAt: .now.addingTimeInterval(60 * 60 * 24 * 365),
        willRenew: true, passBalance: 1, synchronizedAt: .now
    )
    static let showcasePass = BillingSnapshot(
        plusActive: false, subscriptionState: .none,
        productID: MosaicBillingCatalog.eventPassProductID,
        expiresAt: nil, willRenew: false, passBalance: 1, synchronizedAt: .now
    )
}

private struct MosaicReducedMotionRevealShowcase: View {
    @State private var playback = RevealPlaybackStore()
    private let event = MosaicShowcaseFixtures.makeHundredTileEvent()

    var body: some View {
        ScrollView {
            ArtworkRevealBoard(event: event, decryptedArtworkURL: nil, playback: playback)
                .padding(20)
        }
        .porcelainBackground()
        .navigationTitle("Reduced-motion reveal")
        .navigationBarTitleDisplayMode(.inline)
        .task { playback.prepare(event: event, accountID: nil, reduceMotion: true) }
    }
}

private struct MosaicShowcaseCamera: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if dynamicTypeSize.isAccessibilitySize {
                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundStyle(MosaicTheme.accentForeground)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Camera Mosaic")
                                    .font(.caption)
                                    .foregroundStyle(MosaicTheme.muted)
                                Text("Willow Street Garden Day")
                                    .font(.headline)
                                    .lineLimit(3)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(MosaicTheme.muted)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: MosaicTheme.minimumHitTarget, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Camera Mosaic, Willow Street Garden Day")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("camera.eventPicker.accessibility")
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2.fill").foregroundStyle(MosaicTheme.accentForeground)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("LOADED MOSAIC").font(.caption2.weight(.bold)).tracking(1.1).foregroundStyle(MosaicTheme.muted)
                                Text("Willow Street Garden Day").font(.headline)
                            }
                            Spacer(); Image(systemName: "chevron.up.chevron.down").font(.caption)
                        }
                        .accessibilityIdentifier("camera.eventPicker.standard")
                    }
                    DisposableCameraShell(event: MosaicShowcaseFixtures.makeEvents()[0].summary, shotsRemaining: 19) {
                        Image("OnboardingBedroom").resizable().scaledToFill()
                            .frame(width: 310, height: 413).clipped()
                    }
                    CameraShutter().accessibilityLabel("Take photo, 19 shots remaining")
                        .accessibilityIdentifier("camera.shutter")
                    HStack(spacing: 12) {
                        FilmCanister(frameCount: 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your sealed roll").font(MosaicTheme.display(24, weight: .semibold))
                            Text("5 kept · develops at reveal").font(.caption).foregroundStyle(MosaicTheme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    Text("Only you can see these before reveal.").font(.footnote).foregroundStyle(MosaicTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(Array(CuratedArtwork.collection.prefix(3).enumerated()), id: \.element.id) { index, art in
                                Image(art.assetName).resizable().scaledToFill().frame(width: 104, height: 134).clipped()
                                    .padding(6).padding(.bottom, 14).background(.white)
                                    .overlay(alignment: .bottomLeading) {
                                        Text("FRAME \(String(format: "%02d", index + 1))")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.black.opacity(0.58)).padding(7)
                                    }
                                    .shadow(color: MosaicTheme.warmShadow, radius: 5, y: 3)
                            }
                        }
                    }.scrollIndicators(.hidden)
                }.padding(20)
            }
            .porcelainBackground()
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MosaicShowcaseCameraReview: View {
    private enum Result { case reviewing, kept, retake }
    @State private var result = Result.reviewing

    var body: some View {
        NavigationStack {
            Group {
                switch result {
                case .reviewing:
                    if let jpeg = UIImage(named: "OnboardingBedroom")?.jpegData(compressionQuality: 0.9) {
                        PhotoReviewView(jpeg: jpeg, look: .garden) {
                            result = .retake
                        } keep: {
                            result = .kept
                        }
                    }
                case .kept:
                    VStack(spacing: 20) {
                        FilmCanister(frameCount: 1).scaleEffect(1.4)
                        Text("Frame sealed").font(MosaicTheme.display(28, weight: .semibold))
                        Text("1 kept · 23 exposures remaining")
                            .foregroundStyle(MosaicTheme.muted)
                        Text("Only you can see this frame before reveal.")
                            .font(.footnote).foregroundStyle(MosaicTheme.muted)
                    }
                    .padding(24)
                    .accessibilityIdentifier("camera.review.kept")
                case .retake:
                    VStack(spacing: 20) {
                        CameraShutter()
                        Text("Ready for another frame").font(MosaicTheme.display(28, weight: .semibold))
                        Text("24 exposures remaining · retakes use no shot")
                            .foregroundStyle(MosaicTheme.muted)
                    }
                    .padding(24)
                    .accessibilityIdentifier("camera.review.retakeReady")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .porcelainBackground()
            .navigationTitle("Camera review")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MosaicShowcaseCameraDenied: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DisposableCameraShell(event: MosaicShowcaseFixtures.makeEvents()[0].summary, shotsRemaining: 19) {
                        ZStack {
                            MosaicTheme.ink
                            Image(systemName: "camera.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(MosaicTheme.porcelain.opacity(0.65))
                        }
                    }
                    VStack(spacing: 10) {
                        Text("Camera access is off").font(.headline)
                        Text("Enable Camera in Settings to use this Mosaic's disposable roll.")
                            .font(.subheadline).foregroundStyle(MosaicTheme.muted)
                        Button("Open Settings") {}
                            .buttonStyle(MosaicPrimaryButtonStyle())
                    }
                    .porcelainCard()
                    Text("Your sealed roll").font(MosaicTheme.display(25, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .porcelainBackground()
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
