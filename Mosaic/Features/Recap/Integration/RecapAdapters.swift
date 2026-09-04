import Foundation
import Supabase
import UIKit

struct AppStoreRecapAdapter: RecapDataProviding {
    let challenge: KindnessChallenge

    func loadRecap(challengeID: UUID) async throws -> (RecapMeta, [RecapSource]) {
        let museumAsset = await cachedMuseumAsset(
            challengeID: challenge.id,
            revision: challenge.artworkPackageRevision
        )
        let accepted = challenge.contributions.filter { [.verified, .placed, .revealed, .selfAttested].contains($0.status) }
        let participantCount = Set(accepted.map(\.participantID)).count
        let missionTotals = Dictionary(grouping: accepted, by: { RecapMissionCategory(rawValue: $0.mission.category.rawValue) ?? .community })
            .mapValues(\.count)
        let impact = RecapImpactReceipt(
            acceptedActions: accepted.count,
            participantCount: participantCount,
            missionTotals: missionTotals,
            passTheTileJoins: accepted.filter(\.isRevived).count,
            organizerUnits: [],
            version: challenge.impactReceiptVersion
        )
        let meta = RecapMeta(
            challengeID: challenge.id,
            challengeName: challenge.name,
            groupName: challenge.groupName,
            startDate: challenge.startDate,
            endDate: challenge.revealDate,
            goal: challenge.goal,
            revealed: true,
            impact: impact,
            mosaicVersion: challenge.mosaicVersion,
            localeIdentifier: Locale.current.identifier,
            timeZoneIdentifier: TimeZone.current.identifier,
            theme: challenge.theme,
            artworkMode: challenge.artworkMode,
            boardSide: challenge.sealedArtwork?.boardSide,
            artworkCrop: museumAsset.crop,
            artworkFileURL: museumAsset.url
        )
        let sources = challenge.contributions.compactMap { contribution -> RecapSource? in
            let memory = contribution.memory
            let content: RecapMemoryContent
            switch memory?.kind {
            case .photo, .photoWithNote:
                content = .photo(
                    asset: RecapMediaAsset(
                        localURL: LocalMemoryStore.url(for: memory?.localAssetName), remotePath: nil,
                        version: memory?.mediaVersion ?? 1, pixelWidth: nil, pixelHeight: nil
                    ),
                    note: memory?.note
                )
            case .reflection:
                guard let note = memory?.note else { content = .tileOnly; break }
                content = .reflection(note)
            case .tileOnly, nil:
                content = .tileOnly
            }
            let localImage = LocalMemoryStore.url(for: memory?.localAssetName).flatMap { UIImage(contentsOfFile: $0.path)?.cgImage }
            return RecapSource(
                id: contribution.id,
                origin: .contribution,
                contributionID: contribution.id,
                participantID: contribution.participantID,
                participantDisplayName: contribution.contributor,
                attributionAllowed: memory?.attributionAllowed ?? (contribution.contributor != nil),
                category: RecapMissionCategory(rawValue: contribution.mission.category.rawValue) ?? .community,
                acceptedAt: contribution.createdAt,
                content: content,
                tile: RecapTileDescriptor(
                    category: RecapMissionCategory(rawValue: contribution.mission.category.rawValue) ?? .community,
                    emotion: RecapEmotion(rawValue: contribution.emotion.rawValue) ?? .hopeful,
                    isRevived: contribution.isRevived,
                    finalPosition: contribution.tilePosition ?? challenge.contributions.firstIndex(of: contribution) ?? 0
                ),
                eligibility: RecapEligibility(
                    accepted: accepted.contains(contribution),
                    recapConsent: memory?.recapConsent ?? contribution.sharedMemory,
                    mediaExists: memory != nil || contribution.sharedMemory,
                    isDeleted: contribution.isDeleted,
                    isReported: contribution.isReported,
                    contributorIsBlocked: contribution.contributorIsBlocked,
                    viewerIsAuthorized: true
                ),
                mediaVersion: memory?.mediaVersion ?? 1,
                consentVersion: memory?.consentVersion ?? 1,
                perceptualHash: localImage.flatMap { RecapCurator.averageHash($0) },
                blurScore: localImage.flatMap { RecapCurator.laplacianVariance($0) }
            )
        }
        let sharedSources = challenge.sharedMoments.compactMap { moment -> RecapSource? in
            guard moment.lifecycle == .approved, moment.revealConsent, moment.exportConsent else { return nil }
            let url = ProtectedSharedMomentStore.localURL(for: moment.localAssetName)
            let asset = RecapMediaAsset(localURL: url, remotePath: moment.remoteMediaPath,
                                        version: moment.mediaVersion, pixelWidth: nil, pixelHeight: nil)
            let content: RecapMemoryContent
            switch moment.mediaKind {
            case .photo:
                content = .photo(asset: asset, note: moment.note)
            case .video:
                content = .video(asset: asset, note: moment.note, duration: moment.durationSeconds)
            case .note:
                guard let note = moment.note else { return nil }
                content = .reflection(note)
            }
            let image = moment.mediaKind == .photo ? url.flatMap { UIImage(contentsOfFile: $0.path)?.cgImage } : nil
            let mediaExists = moment.mediaKind == .note ? moment.note != nil : (url != nil || moment.remoteMediaPath != nil)
            return RecapSource(
                id: moment.id, origin: .sharedMoment, contributionID: nil,
                participantID: moment.creatorID, participantDisplayName: nil,
                attributionAllowed: moment.attribution == .permitted,
                category: moment.editorialCategory.flatMap { RecapMissionCategory(rawValue: $0.rawValue) },
                acceptedAt: moment.createdAt, content: content, tile: nil,
                eligibility: RecapEligibility(
                    accepted: true, recapConsent: moment.exportConsent, mediaExists: mediaExists,
                    isDeleted: false, isReported: false, contributorIsBlocked: false, viewerIsAuthorized: true
                ),
                mediaVersion: moment.mediaVersion, consentVersion: moment.consentVersion,
                perceptualHash: image.flatMap { RecapCurator.averageHash($0) },
                blurScore: image.flatMap { RecapCurator.laplacianVariance($0) }
            )
        }
        return (meta, sources + sharedSources)
    }

    private func cachedMuseumAsset(
        challengeID: UUID,
        revision: Int?
    ) async -> (url: URL?, crop: NormalizedArtworkCrop?) {
        guard let revision else { return (nil, nil) }
        let cache = RevealArtworkCache()
        let exportURL = await cache.cachedExportURL(challengeID: challengeID, revision: revision)
        let displayURL = await cache.cachedDisplayURL(challengeID: challengeID, revision: revision)
        let url = exportURL ?? displayURL
        let metadata = try? await cache.cachedMetadata(challengeID: challengeID, revision: revision)
        return (url, metadata?.crop)
    }
}

actor SupabaseRecapAdapter: RecapDataProviding, RecapExportRecording, RecapCloudPublishing {
    private let client: SupabaseClient

    init(configuration: SupabaseConfiguration) {
        client = MosaicSupabaseClientFactory.make(configuration: configuration)
    }

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadRecap(challengeID: UUID) async throws -> (RecapMeta, [RecapSource]) {
        _ = try await client.restoreOrCreateMosaicSession()
        let challenge: RecapChallengeRecord = try await client.from("challenges")
            .select("id,name,group_name,goal,start_at,reveal_at,status,mosaic_version,impact_receipt_version,theme_id,theme_palette_id,theme_seed,theme_revision,artwork_mode,board_side,artwork_package_revision")
            .eq("id", value: challengeID.uuidString).single().execute().value
        let impact: RecapImpactRecord? = try? await client.from("impact_receipts")
            .select().eq("challenge_id", value: challengeID.uuidString).single().execute().value
        let records: [RecapSourceRecord] = try await client.from("recap_sources")
            .select().eq("challenge_id", value: challengeID.uuidString).order("accepted_at").execute().value

        var sources: [RecapSource] = []
        for record in records {
            let localURL = try await downloadMemoryIfPresent(record)
            let content: RecapMemoryContent
            if record.resolvedMediaKind == .video, record.mediaPath != nil {
                content = .video(
                    asset: RecapMediaAsset(localURL: localURL, remotePath: record.mediaPath,
                                           version: record.mediaVersion, pixelWidth: nil, pixelHeight: nil),
                    note: record.storyText,
                    duration: record.durationSeconds
                )
            } else if record.mediaPath != nil {
                content = .photo(asset: RecapMediaAsset(localURL: localURL, remotePath: record.mediaPath,
                                                        version: record.mediaVersion, pixelWidth: nil, pixelHeight: nil), note: record.storyText)
            } else if let story = record.storyText {
                content = .reflection(story)
            } else {
                content = .tileOnly
            }
            let image = record.resolvedMediaKind == .photo ? localURL.flatMap { UIImage(contentsOfFile: $0.path)?.cgImage } : nil
            sources.append(RecapSource(
                id: record.id, origin: record.origin, contributionID: record.contributionId, participantID: record.participantId,
                participantDisplayName: record.participantDisplayName, attributionAllowed: record.attributionAllowed,
                category: record.category, acceptedAt: record.acceptedAt, content: content,
                tile: record.category.map { category in
                    RecapTileDescriptor(category: category, emotion: RecapEmotion(rawValue: record.emotion ?? "") ?? .hopeful,
                                        isRevived: record.isRevived, finalPosition: record.tilePosition ?? sources.count)
                },
                eligibility: RecapEligibility(accepted: record.accepted, recapConsent: record.recapConsent,
                                              mediaExists: record.mediaExists, isDeleted: record.isDeleted,
                                              isReported: record.isReported, contributorIsBlocked: record.contributorIsBlocked,
                                              viewerIsAuthorized: true),
                mediaVersion: record.mediaVersion, consentVersion: record.consentVersion,
                perceptualHash: image.flatMap { RecapCurator.averageHash($0) },
                blurScore: image.flatMap { RecapCurator.laplacianVariance($0) }
            ))
        }
        let missionTotals = impact?.missionTotals.reduce(into: [RecapMissionCategory: Int]()) { result, item in
            if let category = RecapMissionCategory(rawValue: item.key) { result[category] = item.value }
        } ?? Dictionary(grouping: sources.filter { $0.origin == .contribution }.compactMap(\.category), by: { $0 }).mapValues(\.count)
        let receipt = RecapImpactReceipt(
            acceptedActions: impact?.acceptedActions ?? sources.filter { $0.origin == .contribution }.count,
            participantCount: impact?.participantCount ?? Set(sources.filter { $0.origin == .contribution }.map(\.participantID)).count,
            missionTotals: missionTotals,
            passTheTileJoins: impact?.passTheTileJoins ?? 0,
            organizerUnits: impact?.organizerUnits.map { RecapOrganizerUnit(label: $0.label, value: $0.value) } ?? [],
            version: impact?.version ?? challenge.impactReceiptVersion
        )
        let museumAsset = await cachedMuseumAsset(
            challengeID: challenge.id,
            revision: challenge.artworkPackageRevision
        )
        let meta = RecapMeta(challengeID: challenge.id, challengeName: challenge.name, groupName: challenge.groupName,
                             startDate: challenge.startAt, endDate: challenge.revealAt, goal: challenge.goal,
                             revealed: challenge.status == "revealed", impact: receipt, mosaicVersion: challenge.mosaicVersion,
                             localeIdentifier: Locale.current.identifier, timeZoneIdentifier: TimeZone.current.identifier,
                             theme: challenge.themeSelection, artworkMode: challenge.artworkMode ?? .legacy,
                             boardSide: challenge.boardSide, artworkCrop: museumAsset.crop,
                             artworkFileURL: museumAsset.url)
        return (meta, sources)
    }

    private func cachedMuseumAsset(
        challengeID: UUID,
        revision: Int?
    ) async -> (url: URL?, crop: NormalizedArtworkCrop?) {
        guard let revision else { return (nil, nil) }
        let cache = RevealArtworkCache()
        let exportURL = await cache.cachedExportURL(challengeID: challengeID, revision: revision)
        let displayURL = await cache.cachedDisplayURL(challengeID: challengeID, revision: revision)
        let url = exportURL ?? displayURL
        let metadata = try? await cache.cachedMetadata(challengeID: challengeID, revision: revision)
        return (url, metadata?.crop)
    }

    func record(_ status: RecapExportStatus, request: RecapExportRequest, progress: Double, outputPath: String?, error: String?) async throws {
        guard let userID = client.auth.currentSession?.user.id else { return }
        let fingerprint = try await RecapExportCache.shared.fingerprint(for: request)
        let record = RecapExportUpsert(
            challengeId: request.meta.challengeID, creatorId: userID, fingerprint: fingerprint,
            presetId: request.presetID, musicId: request.audio.trackID, musicTrimOffset: request.audio.trimOffset,
            options: request.options, status: databaseStatus(status), progress: min(max(progress, 0), 1),
            storagePath: outputPath, error: error, completedAt: status == .completedLocal || status == .completedUploaded ? Date() : nil
        )
        try await client.from("recap_exports").upsert(record, onConflict: "creator_id,fingerprint").execute()
    }

    func publish(file: URL, request: RecapExportRequest) async throws -> String {
        guard let userID = client.auth.currentSession?.user.id else {
            throw NSError(domain: "Mosaic.Recap", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Sign in before publishing a recap."])
        }
        let fingerprint = try await RecapExportCache.shared.fingerprint(for: request)
        let path = "\(userID.uuidString.lowercased())/\(request.meta.challengeID.uuidString.lowercased())/\(fingerprint).mp4"
        let thumbnailPath = "\(userID.uuidString.lowercased())/\(request.meta.challengeID.uuidString.lowercased())/\(fingerprint)-widget.jpg"
        let music = RecapMusicCatalog.track(id: request.audio.trackID)
        let timeline = RecapTimeline.build(
            sources: request.sources,
            preset: request.preset,
            audio: request.audio,
            trackBeats: music?.beats ?? [],
            options: request.options,
            reduceMotion: request.reduceMotion
        )
        let renderRequest = RecapRenderRequest(
            meta: request.meta,
            timeline: timeline,
            options: request.options,
            music: music
        )
        let thumbnailURL = try await MainActor.run {
            try RecapShareService.makeStaticCard(request: renderRequest, kind: .finalMosaic)
        }
        defer { try? FileManager.default.removeItem(at: thumbnailURL) }

        // Both object names are persisted first because Storage RLS only accepts
        // files explicitly referenced by an export owned by this user.
        try await record(.completedLocal, request: request, progress: 1, outputPath: path, error: nil)
        struct PreparedPaths: Encodable {
            let storagePath: String
            let thumbnailPath: String
            enum CodingKeys: String, CodingKey {
                case storagePath = "storage_path"
                case thumbnailPath = "thumbnail_path"
            }
        }
        try await client.from("recap_exports")
            .update(PreparedPaths(storagePath: path, thumbnailPath: thumbnailPath))
            .eq("creator_id", value: userID.uuidString)
            .eq("fingerprint", value: fingerprint)
            .execute()
        try await client.storage.from("recap-exports").upload(
            path, fileURL: file, options: FileOptions(cacheControl: "31536000", contentType: "video/mp4", upsert: false)
        )
        try await client.storage.from("recap-exports").upload(
            thumbnailPath,
            fileURL: thumbnailURL,
            options: FileOptions(cacheControl: "31536000", contentType: "image/jpeg", upsert: false)
        )
        try await record(.completedUploaded, request: request, progress: 1, outputPath: path, error: nil)
        struct Published: Encodable { let visibility: String; let status: String }
        try await client.from("recap_exports")
            .update(Published(visibility: "challenge", status: "completed_uploaded"))
            .eq("creator_id", value: userID.uuidString)
            .eq("fingerprint", value: fingerprint)
            .execute()
        return path
    }

    private func downloadMemoryIfPresent(_ record: RecapSourceRecord) async throws -> URL? {
        guard record.mediaPath != nil else { return nil }
        let data: Data
        if let contributionID = record.contributionId {
            struct Body: Encodable { let contributionId: UUID; let kind: String }
            struct Response: Decodable { let url: URL }
            let response: Response = try await client.functions.invoke(
                "get-private-media-url", options: FunctionInvokeOptions(body: Body(contributionId: contributionID, kind: "memory"))
            )
            data = try await URLSession.shared.data(from: response.url).0
        } else if let path = record.mediaPath {
            data = try await client.storage.from("recap-memories").download(path: path)
        } else { return nil }
        let fileExtension = record.resolvedMediaKind == .video ? "mov" : "jpg"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recap-memory-\(record.id.uuidString).\(fileExtension)")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }

    private func databaseStatus(_ status: RecapExportStatus) -> String {
        switch status {
        case .completedLocal: "completed_local"
        case .completedUploaded: "completed_uploaded"
        default: status.rawValue
        }
    }
}

private struct RecapChallengeRecord: Decodable {
    let id: UUID; let name: String; let groupName: String; let goal: Int; let startAt: Date; let revealAt: Date
    let status: String; let mosaicVersion: Int; let impactReceiptVersion: Int
    let themeId: String?; let themePaletteId: String?; let themeSeed: Int?; let themeRevision: Int?
    let artworkMode: ArtworkMode?; let boardSide: Int?; let artworkPackageRevision: Int?
    var themeSelection: ThemeSelection {
        guard let id = themeId,
              KinderThemeCatalog.all.contains(where: { $0.id == id }),
              let palette = KinderThemePaletteID(rawValue: themePaletteId ?? "") else { return .fallback }
        return ThemeSelection(themeID: id, paletteID: palette,
                              seed: themeSeed ?? KinderThemeCatalog.theme(id: id).seed,
                              revision: themeRevision ?? KinderThemeCatalog.revision)
    }
    enum CodingKeys: String, CodingKey {
        case id, name, goal, status
        case groupName = "group_name"; case startAt = "start_at"; case revealAt = "reveal_at"
        case mosaicVersion = "mosaic_version"; case impactReceiptVersion = "impact_receipt_version"
        case themeId = "theme_id"; case themePaletteId = "theme_palette_id"
        case themeSeed = "theme_seed"; case themeRevision = "theme_revision"
        case artworkMode = "artwork_mode"; case boardSide = "board_side"
        case artworkPackageRevision = "artwork_package_revision"
    }
}

private struct RecapImpactRecord: Decodable {
    struct Unit: Decodable { let label: String; let value: String }
    let version: Int; let acceptedActions: Int; let participantCount: Int; let missionTotals: [String: Int]
    let passTheTileJoins: Int; let organizerUnits: [Unit]
    enum CodingKeys: String, CodingKey {
        case version; case acceptedActions = "accepted_actions"; case participantCount = "participant_count"
        case missionTotals = "mission_totals"; case passTheTileJoins = "pass_the_tile_joins"; case organizerUnits = "organizer_units"
    }
}

private struct RecapSourceRecord: Decodable {
    let id: UUID; let origin: RecapSourceOrigin; let contributionId: UUID?; let participantId: UUID; let participantDisplayName: String?
    let attributionAllowed: Bool; let category: RecapMissionCategory?; let acceptedAt: Date; let mediaPath: String?
    let storyText: String?; let emotion: String?; let tilePosition: Int?; let isRevived: Bool; let mediaVersion: Int
    let consentVersion: Int; let accepted: Bool; let recapConsent: Bool; let mediaExists: Bool; let isDeleted: Bool
    let isReported: Bool; let contributorIsBlocked: Bool; let mediaKind: SharedMomentMediaKind?
    let mediaMimeType: String?; let durationSeconds: Double?
    enum CodingKeys: String, CodingKey {
        case id, origin, category, emotion, accepted
        case contributionId = "contribution_id"; case participantId = "participant_id"
        case participantDisplayName = "participant_display_name"; case attributionAllowed = "attribution_allowed"
        case acceptedAt = "accepted_at"; case mediaPath = "media_path"; case storyText = "story_text"
        case tilePosition = "tile_position"; case isRevived = "is_revived"; case mediaVersion = "media_version"
        case consentVersion = "consent_version"; case recapConsent = "recap_consent"; case mediaExists = "media_exists"
        case isDeleted = "is_deleted"; case isReported = "is_reported"; case contributorIsBlocked = "contributor_is_blocked"
        case mediaKind = "media_kind"; case mediaMimeType = "media_mime_type"; case durationSeconds = "duration_seconds"
    }

    var resolvedMediaKind: SharedMomentMediaKind {
        if let mediaKind { return mediaKind }
        guard let mediaPath else { return .note }
        return mediaPath.lowercased().hasSuffix(".mov") || mediaPath.lowercased().hasSuffix(".mp4") ? .video : .photo
    }
}

private struct RecapExportUpsert: Encodable {
    let challengeId: UUID; let creatorId: UUID; let fingerprint: String; let presetId: String; let musicId: String?
    let musicTrimOffset: Double; let options: RecapDetailsOptions; let status: String; let progress: Double
    let storagePath: String?; let error: String?; let completedAt: Date?
    enum CodingKeys: String, CodingKey {
        case fingerprint, options, status, progress, error
        case challengeId = "challenge_id"; case creatorId = "creator_id"; case presetId = "preset_id"; case musicId = "music_id"
        case musicTrimOffset = "music_trim_offset"; case storagePath = "storage_path"; case completedAt = "completed_at"
    }
}
