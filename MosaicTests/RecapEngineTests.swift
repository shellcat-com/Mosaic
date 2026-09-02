import AVFoundation
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Mosaic

@Suite(.serialized)
struct RecapEngineTests {
    @Test func presetCatalogContainsNineAuthoredEditsAndNewTemplates() {
        #expect(RecapPresetCatalog.all.count == 9)
        #expect(RecapPresetCatalog.recommended.id == "golden")
        #expect(Set(RecapPresetCatalog.all.map(\.id)).count == 9)
        #expect(RecapPresetCatalog.all.prefix(4).map(\.id) == ["golden", "porcelain-print", "kiln-tape", "pocket-kiln"])
        #expect(RecapPresetCatalog.quietMoments.nominalMontageDuration == 8)
        #expect(RecapPresetCatalog.goldenMosaic.defaultMusicID == "summer")
        #expect(RecapPresetCatalog.actionDiary.chrome == .memoryCamera)
        #expect(RecapPresetCatalog.porcelainPrint.visualStyle == .porcelainPrint)
        #expect(RecapPresetCatalog.porcelainPrint.nominalClipCount == 9)
        #expect(RecapPresetCatalog.porcelainPrint.perMemory == 1.35)
        #expect(RecapPresetCatalog.porcelainPrint.defaultMusicID == "fresh")
        #expect(RecapPresetCatalog.kilnTape.visualStyle == .kilnTape)
        #expect(RecapPresetCatalog.kilnTape.nominalClipCount == 10)
        #expect(RecapPresetCatalog.kilnTape.defaultMusicID == "summer")
        #expect(RecapPresetCatalog.pocketKiln.visualStyle == .pocketKiln)
        #expect(RecapPresetCatalog.pocketKiln.nominalClipCount == 8)
        #expect(RecapPresetCatalog.pocketKiln.defaultMusicID == "spark")
        #expect(RecapFrameRenderer.version == 3)
    }

    @Test func timelineHasFixedStorySectionsAndDeterministicTiming() {
        let sources = (0..<10).map { source(index: $0) }
        let first = timeline(sources: sources)
        let second = timeline(sources: sources)

        #expect(first == second)
        #expect(first.segments.first?.phase == .intro)
        #expect(first.segments.first?.duration == 4)
        #expect(first.segments.last?.phase == .outro)
        #expect(first.segments.last?.duration == 2.1)
        #expect(abs(first.totalDuration - 27.1) < 0.000_1)
        #expect(first.segments.contains { $0.phase == .finalReveal && $0.duration == 2.4 })
        #expect(first.segments.contains { $0.phase == .impactReceipt && $0.duration == 2.6 })
    }

    @Test func beatSnappingHonorsToleranceClampsAndLastNominalHold() {
        let preset = RecapPresetCatalog.goldenMosaic
        let sources = (0..<3).map { source(index: $0) }
        let timeline = RecapTimeline.build(
            sources: sources,
            preset: preset,
            audio: .init(trackID: "summer", trimOffset: 0),
            trackBeats: [5.8, 7.7, 9.6],
            options: .init(),
            reduceMotion: false
        )
        let memories = timeline.segments.filter { $0.phase == .memory }

        #expect(abs(memories[0].duration - 1.8) < 0.000_1)
        #expect(memories.allSatisfy { $0.duration >= preset.perMemory * 0.6 && $0.duration <= preset.perMemory * 1.6 })
        #expect(abs(memories.last!.duration - preset.perMemory) < 0.000_1)
    }

    @Test func trimOffsetAdjustsBeatGridExactlyOnceAndLoops() {
        #expect(RecapTimeline.adjustedBeats([1, 2, 3], trimOffset: 1.5) == [0.5, 1.5])
        let track = RecapMusicTrack(
            id: "fixture", name: "Fixture", artist: "Mosaic", resourceName: nil,
            categories: [.community], mood: "Test", bpm: 60, duration: 4,
            beats: [0, 1, 2, 3], license: "Test", licenseURL: nil,
            sourceURL: nil, attribution: "Fixture", artworkColors: [], assetChecksum: nil,
            verifiedAt: nil, waveformBins: []
        )
        #expect(RecapBeatDetector.adjustedLoopingBeats(track: track, offset: 1.5, timelineDuration: 7) == [0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5])
    }

    @Test func templateTransitionsExposeOutgoingMemoryAndHonorReduceMotion() throws {
        let sources = (0..<3).map { source(index: $0) }
        let dissolve = templateTimeline(preset: RecapPresetCatalog.porcelainPrint, sources: sources)
        let dissolveMemories = dissolve.segments.filter { $0.phase == .memory }
        let second = try #require(dissolveMemories.dropFirst().first)
        let entering = dissolve.frame(at: second.start + 0.1)
        #expect(entering.segmentIndex == 2)
        #expect(entering.sourceIndex == second.sourceIndex)
        #expect(entering.previousSourceIndex == dissolveMemories[0].sourceIndex)
        #expect(entering.transitionProgress > 0 && entering.transitionProgress < 1)
        #expect(dissolve.frame(at: second.start + 0.36).transitionProgress == 1)

        let snap = templateTimeline(preset: RecapPresetCatalog.kilnTape, sources: sources)
        let snapSecond = try #require(snap.segments.filter { $0.phase == .memory }.dropFirst().first)
        #expect(snap.frame(at: snapSecond.start).transitionProgress == 1)

        let reduced = templateTimeline(preset: RecapPresetCatalog.kilnTape, sources: sources, reduceMotion: true)
        let reducedSecond = try #require(reduced.segments.filter { $0.phase == .memory }.dropFirst().first)
        let reducedFrame = reduced.frame(at: reducedSecond.start + 0.05)
        #expect(reducedFrame.transitionProgress > 0 && reducedFrame.transitionProgress < 1)
        #expect(reducedFrame.scale == 1)
        #expect(reducedFrame.panX == 0)
    }

    @Test func memoryMotionAlternatesAndReduceMotionStopsIt() {
        let animated = timeline(sources: (0..<2).map { source(index: $0) })
        let memories = animated.segments.filter { $0.phase == .memory }
        let first = animated.frame(at: memories[0].start + memories[0].duration * 0.25)
        let second = animated.frame(at: memories[1].start + memories[1].duration * 0.25)
        #expect(first.panX < 0)
        #expect(second.panX > 0)
        #expect(first.scale < second.scale)

        let still = timeline(sources: (0..<2).map { source(index: $0) }, reduceMotion: true)
        let stillFrame = still.frame(at: still.segments.first(where: { $0.phase == .memory })!.start + 0.4)
        #expect(stillFrame.scale == 1)
        #expect(stillFrame.panX == 0)
    }

    @Test func tileOnlyRecapOmitsMontageButKeepsRevealAndReceipt() {
        let tiles = (0..<6).map { source(index: $0, content: .tileOnly) }
        let result = timeline(sources: tiles)
        #expect(!result.segments.contains { $0.phase == .memory })
        #expect(result.sources.count == 6)
        #expect(result.totalDuration == 11.1)
    }

    @Test func onePhotoAppearsOnceWithoutDuplication() {
        let result = timeline(sources: [source(index: 0)])
        #expect(result.segments.filter { $0.phase == .memory }.count == 1)
    }

    @Test func videoMemoryRendersMovingFramesInsideTheRecap() async throws {
        let videoURL = try await makeVideoFixture()
        defer { try? FileManager.default.removeItem(at: videoURL) }
        let videoSource = source(
            index: 0,
            content: .video(
                asset: .init(localURL: videoURL, remotePath: nil, version: 1,
                             pixelWidth: 320, pixelHeight: 240),
                note: nil,
                duration: 1
            )
        )
        let timeline = timeline(sources: [videoSource], reduceMotion: true)
        let memory = try #require(timeline.segments.first { $0.phase == .memory })
        let request = RecapRenderRequest(meta: recapMeta(), timeline: timeline, options: .init(), music: nil)
        let renderer = RecapFrameRenderer()
        let size = CGSize(width: 360, height: 640)

        let early = try #require(renderer.makeImage(request: request, time: memory.start + memory.duration * 0.2, size: size))
        let late = try #require(renderer.makeImage(request: request, time: memory.start + memory.duration * 0.8, size: size))
        let earlyPixel = try rgba(early, x: 180, y: 300)
        let latePixel = try rgba(late, x: 180, y: 300)

        #expect(Int(earlyPixel.red) > Int(earlyPixel.blue) + 40)
        #expect(Int(latePixel.blue) > Int(latePixel.red) + 40)
    }

    @Test func curationFiltersConsentModerationAndAuthorization() {
        let accepted = source(index: 0)
        let rejected = source(index: 1, eligibility: eligibility(accepted: false))
        let unconsented = source(index: 2, eligibility: eligibility(consent: false))
        let deleted = source(index: 3, eligibility: eligibility(deleted: true))
        let reported = source(index: 4, eligibility: eligibility(reported: true))
        let blocked = source(index: 5, eligibility: eligibility(blocked: true))
        let outsider = source(index: 6, eligibility: eligibility(authorized: false))
        #expect(RecapCurator.curate([outsider, blocked, reported, deleted, unconsented, rejected, accepted]).map(\.id) == [accepted.id])
    }

    @Test func curationGivesEveryParticipantTwoTurnsBeforeThird() {
        let participants = (0..<3).map { uuid($0 + 100) }
        let input = participants.enumerated().flatMap { participantIndex, participant in
            (0..<4).map { item in source(index: participantIndex * 10 + item, participant: participant,
                                         category: RecapMissionCategory.allCases[item]) }
        }
        let result = RecapCurator.curate(input)
        let firstSix = result.prefix(6)
        for participant in participants {
            #expect(firstSix.count(where: { $0.participantID == participant }) == 2)
        }
        #expect(Set(firstSix.map(\.category)).count >= 3)
    }

    @Test func duplicateAndGuardedBlurFilteringPreserveRepresentation() {
        let participant = uuid(200)
        let duplicateA = source(index: 1, participant: participant, hash: 0b1, blur: 180)
        let duplicateB = source(index: 2, participant: participant, hash: 0b11, blur: 190)
        let blurry = source(index: 3, participant: participant, category: .giving, hash: 0xff00, blur: 20)
        let sharp = source(index: 4, participant: participant, category: .giving, hash: 0xffff, blur: 190)
        let onlyBlurry = source(index: 5, participant: uuid(201), category: .support, hash: 0xabcd, blur: 10)
        let result = RecapCurator.curate([duplicateA, duplicateB, blurry, sharp, onlyBlurry])

        #expect(result.contains(where: { $0.id == duplicateA.id }))
        #expect(!result.contains(where: { $0.id == duplicateB.id }))
        #expect(!result.contains(where: { $0.id == blurry.id }))
        #expect(result.contains(where: { $0.id == sharp.id }))
        #expect(result.contains(where: { $0.id == onlyBlurry.id }))
    }

    @Test func fingerprintIsOrderIndependentButTracksMaterialChanges() async throws {
        let first = source(index: 1)
        let second = source(index: 2)
        let base = exportRequest(sources: [first, second])
        let reordered = exportRequest(sources: [second, first])
        let reduced = exportRequest(sources: [first, second], reduceMotion: true)
        let baseHash = try await RecapExportCache.shared.fingerprint(for: base)

        #expect(baseHash == (try await RecapExportCache.shared.fingerprint(for: reordered)))
        #expect(baseHash != (try await RecapExportCache.shared.fingerprint(for: reduced)))
        #expect(baseHash.count == 64)
    }

    @Test func musicMetadataIsCompleteAndCreditsAreExportable() {
        #expect(RecapMusicCatalog.tracks.count == 6)
        for track in RecapMusicCatalog.tracks {
            #expect(track.bpm > 0)
            #expect(track.duration > 0)
            #expect(!track.beats.isEmpty)
            #expect(track.licenseURL != nil)
            #expect(track.sourceURL != nil)
            #expect(!(track.attribution ?? "").isEmpty)
            #expect(track.artworkColors.count >= 2)
            #expect(track.assetChecksum?.count == 64)
            #expect(track.verifiedAt != nil)
            #expect(track.waveformBins.count == 96)
        }
        #expect(RecapMusicCatalog.track(id: "zone")?.name == "Summer Chill Reggaeton | ISLAND")
        #expect(RecapMusicCatalog.noMusic.resourceName == nil)
    }

    @Test func bundledMusicFilesMatchTheVerifiedManifest() throws {
        for track in RecapMusicCatalog.tracks {
            #expect(track.bundledURL != nil)
            let values = try track.bundledURL?.resourceValues(forKeys: [.fileSizeKey])
            #expect((values?.fileSize ?? 0) > 1_000_000)
        }
        #expect(Bundle.main.url(forResource: "MusicManifest", withExtension: "json") != nil)
    }

    @Test func impactReceiptTotalsRemainExact() {
        let meta = recapMeta()
        #expect(meta.impact.acceptedActions == 10)
        #expect(meta.impact.participantCount == 4)
        #expect(meta.impact.missionTotals.values.reduce(0, +) == 10)
        #expect(meta.impact.passTheTileJoins == 2)
    }

    @Test func newTemplatesRenderEveryStoryPhaseAtPreviewAndExportSizes() throws {
        let longReflection = "A small act made the whole neighborhood feel lighter, safer, and more connected than it had that morning."
        let landscapeURL = try makeImageFixture(size: CGSize(width: 640, height: 360), orientation: .up)
        let rotatedURL = try makeImageFixture(size: CGSize(width: 360, height: 640), orientation: .right)
        defer {
            try? FileManager.default.removeItem(at: landscapeURL)
            try? FileManager.default.removeItem(at: rotatedURL)
        }
        let sources = [
            source(index: 0, content: .reflection(longReflection)),
            source(index: 1, content: .photo(asset: .init(localURL: landscapeURL, remotePath: nil, version: 1,
                                                          pixelWidth: 640, pixelHeight: 360),
                                             note: "A deliberately long caption that must remain inside the memory frame without clipping.")),
            source(index: 2, content: .photo(asset: .init(localURL: rotatedURL, remotePath: nil, version: 1,
                                                          pixelWidth: 360, pixelHeight: 640), note: nil)),
            source(index: 3, content: .photo(asset: .init(localURL: nil, remotePath: nil, version: 1,
                                                          pixelWidth: 4032, pixelHeight: 3024), note: "Missing-photo fallback"))
        ]
        let sizes = [CGSize(width: 360, height: 640), CGSize(width: 1080, height: 1920)]

        for preset in newTemplates {
            let timeline = templateTimeline(preset: preset, sources: sources)
            let request = RecapRenderRequest(meta: recapMeta(challengeName: "A Very Long Neighborhood Kindness Celebration"),
                                             timeline: timeline, options: .init(),
                                             music: RecapMusicCatalog.track(id: preset.defaultMusicID))
            let renderer = RecapFrameRenderer()
            for segment in timeline.segments {
                let time = segment.start + segment.duration * 0.55
                for size in sizes {
                    let image = try #require(renderer.makeImage(request: request, time: time, size: size))
                    #expect(image.width == Int(size.width))
                    #expect(image.height == Int(size.height))
                    let bytes = try #require(image.dataProvider?.data)
                    #expect(CFDataGetLength(bytes) > image.width * image.height)
                }
            }

            let intro = try #require(timeline.segments.first { $0.phase == .intro })
            let first = try #require(renderer.makeImage(request: request, time: intro.start + 1, size: sizes[0]))
            let second = try #require(renderer.makeImage(request: request, time: intro.start + 1, size: sizes[0]))
            #expect(first.dataProvider?.data == second.dataProvider?.data)

            for kind in [RecapShareService.StaticCardKind.finalMosaic, .impactReceipt] {
                let url = try RecapShareService.makeStaticCard(request: request, kind: kind)
                defer { try? FileManager.default.removeItem(at: url) }
                let image = try #require(UIImage(contentsOfFile: url.path))
                #expect(image.size.width == 1080)
                #expect(image.size.height == 1920)
            }
        }
    }

    @Test func newTemplateExportsHaveDistinctFingerprints() async throws {
        let tile = source(index: 0, content: .tileOnly)
        let requests = newTemplates.map { preset in
            RecapExportRequest(meta: recapMeta(), sources: [tile], presetID: preset.id,
                               audio: .init(trackID: preset.defaultMusicID, trimOffset: 0), options: .init(),
                               reduceMotion: true, rendererVersion: RecapFrameRenderer.version)
        }
        var fingerprints = Set<String>()
        for request in requests {
            fingerprints.insert(try await RecapExportCache.shared.fingerprint(for: request))
        }
        #expect(fingerprints.count == 3)
    }

    @Test func porcelainPrintExportIsPlayable() async throws {
        try await validatePlayableExport(for: RecapPresetCatalog.porcelainPrint)
    }

    @Test func kilnTapeExportIsPlayable() async throws {
        try await validatePlayableExport(for: RecapPresetCatalog.kilnTape)
    }

    @Test func pocketKilnExportIsPlayable() async throws {
        try await validatePlayableExport(for: RecapPresetCatalog.pocketKiln)
    }

    @Test func composerProducesPlayableVerticalH264AACAndCacheReuse() async throws {
        let request = RecapExportRequest(
            meta: recapMeta(), sources: [source(index: 0, content: .tileOnly)], presetID: "golden",
            audio: .init(trackID: "summer", trimOffset: 2), options: .init(), reduceMotion: true,
            rendererVersion: RecapFrameRenderer.version
        )
        let composer = RecapComposer()
        var output: URL?
        var sawMux = false
        for try await event in await composer.export(request) {
            switch event {
            case let .progress(_, status): sawMux = sawMux || status == .muxing
            case let .completed(url): output = url
            }
        }
        let url = try #require(output)
        defer { try? FileManager.default.removeItem(at: url) }
        let asset = AVURLAsset(url: url)
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let size = try await video.load(.naturalSize)
        let frameRate = try await video.load(.nominalFrameRate)
        let duration = try await asset.load(.duration).seconds
        let videoDescription = try #require(try await video.load(.formatDescriptions).first)
        let audioDescription = try #require(try await audio.load(.formatDescriptions).first)

        #expect(sawMux)
        #expect(size == CGSize(width: 1080, height: 1920))
        #expect(abs(frameRate - 30) < 0.01)
        #expect(abs(duration - 11.1) <= 1.0 / 30.0)
        #expect(CMFormatDescriptionGetMediaSubType(videoDescription) == kCMVideoCodecType_H264)
        #expect(CMFormatDescriptionGetMediaSubType(audioDescription) == kAudioFormatMPEG4AAC)

        let cached = try await RecapExportCache.shared.store(url, for: request)
        #expect(await RecapExportCache.shared.cachedURL(for: request) == cached)
    }

    @Test func composerCancellationStopsWithoutCompletion() async {
        let request = exportRequest(sources: [source(index: 0, content: .tileOnly)])
        let composer = RecapComposer()
        let consumer = Task { () -> Bool in
            do {
                for try await event in await composer.export(request) {
                    if case .completed = event { return true }
                }
            } catch { }
            return false
        }
        try? await Task.sleep(for: .milliseconds(25))
        consumer.cancel()
        #expect(await consumer.value == false)
    }

    private func timeline(sources: [RecapSource], reduceMotion: Bool = false) -> RecapTimeline {
        RecapTimeline.build(sources: sources, preset: RecapPresetCatalog.goldenMosaic, audio: .silent,
                            trackBeats: [], options: .init(), reduceMotion: reduceMotion)
    }

    private func exportRequest(sources: [RecapSource], reduceMotion: Bool = false) -> RecapExportRequest {
        RecapExportRequest(meta: recapMeta(), sources: sources, presetID: "golden", audio: .silent,
                           options: .init(), reduceMotion: reduceMotion, rendererVersion: RecapFrameRenderer.version)
    }

    private var newTemplates: [RecapPreset] {
        [RecapPresetCatalog.porcelainPrint, RecapPresetCatalog.kilnTape, RecapPresetCatalog.pocketKiln]
    }

    private func validatePlayableExport(for preset: RecapPreset) async throws {
        let request = RecapExportRequest(
            meta: recapMeta(), sources: [source(index: 0, content: .tileOnly)], presetID: preset.id,
            audio: .init(trackID: preset.defaultMusicID, trimOffset: 0), options: .init(),
            reduceMotion: true, rendererVersion: RecapFrameRenderer.version
        )
        var output: URL?
        for try await event in await RecapComposer(maximumFrameCount: 60).export(request) {
            if case let .completed(url) = event { output = url }
        }
        let url = try #require(output)
        defer { try? FileManager.default.removeItem(at: url) }

        let asset = AVURLAsset(url: url)
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        #expect(abs(try await asset.load(.duration).seconds - 2) <= 1.0 / 30.0)
        #expect(try await video.load(.naturalSize) == CGSize(width: 1080, height: 1920))
        #expect(abs(try await video.load(.nominalFrameRate) - 30) < 0.01)
        #expect(CMFormatDescriptionGetMediaSubType(try #require(try await video.load(.formatDescriptions).first)) == kCMVideoCodecType_H264)
        #expect(CMFormatDescriptionGetMediaSubType(try #require(try await audio.load(.formatDescriptions).first)) == kAudioFormatMPEG4AAC)
    }

    private func templateTimeline(
        preset: RecapPreset,
        sources: [RecapSource],
        reduceMotion: Bool = false
    ) -> RecapTimeline {
        RecapTimeline.build(sources: sources, preset: preset, audio: .silent, trackBeats: [],
                            options: .init(), reduceMotion: reduceMotion)
    }

    private func recapMeta(challengeName: String = "A Kinder Block") -> RecapMeta {
        RecapMeta(
            challengeID: uuid(900), challengeName: challengeName, groupName: "Mosaic Neighbors",
            startDate: Date(timeIntervalSince1970: 1_700_000_000), endDate: Date(timeIntervalSince1970: 1_700_086_400),
            goal: 12, revealed: true,
            impact: RecapImpactReceipt(acceptedActions: 10, participantCount: 4,
                                       missionTotals: [.community: 6, .giving: 4], passTheTileJoins: 2,
                                       organizerUnits: [.init(label: "Meals shared", value: "18")], version: 3),
            mosaicVersion: 5, localeIdentifier: "en_US", timeZoneIdentifier: "America/Chicago"
        )
    }

    private func source(
        index: Int,
        participant: UUID? = nil,
        category: RecapMissionCategory = .community,
        content: RecapMemoryContent? = nil,
        eligibility: RecapEligibility? = nil,
        hash: UInt64? = nil,
        blur: Double? = 180
    ) -> RecapSource {
        let id = uuid(index + 1)
        return RecapSource(
            id: id, contributionID: id, participantID: participant ?? uuid(index + 500),
            participantDisplayName: "Neighbor \(index)", attributionAllowed: true, category: category,
            acceptedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
            content: content ?? .reflection("A small act made the whole day feel lighter."),
            tile: .init(category: category, emotion: .hopeful, isRevived: index.isMultiple(of: 4), finalPosition: index),
            eligibility: eligibility ?? Self.eligibility(), mediaVersion: 1, consentVersion: 1,
            perceptualHash: hash, blurScore: blur
        )
    }

    private static func eligibility(
        accepted: Bool = true,
        consent: Bool = true,
        deleted: Bool = false,
        reported: Bool = false,
        blocked: Bool = false,
        authorized: Bool = true
    ) -> RecapEligibility {
        RecapEligibility(accepted: accepted, recapConsent: consent, mediaExists: true, isDeleted: deleted,
                         isReported: reported, contributorIsBlocked: blocked, viewerIsAuthorized: authorized)
    }

    private func eligibility(
        accepted: Bool = true,
        consent: Bool = true,
        deleted: Bool = false,
        reported: Bool = false,
        blocked: Bool = false,
        authorized: Bool = true
    ) -> RecapEligibility {
        Self.eligibility(accepted: accepted, consent: consent, deleted: deleted, reported: reported,
                         blocked: blocked, authorized: authorized)
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", value))!
    }

    private func makeImageFixture(size: CGSize, orientation: UIImage.Orientation) throws -> URL {
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0.91, green: 0.33, blue: 0.18, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.12, green: 0.18, blue: 0.38, alpha: 1).setFill()
            context.fill(CGRect(x: size.width * 0.16, y: size.height * 0.2,
                                width: size.width * 0.68, height: size.height * 0.6))
        }
        let oriented = try #require(image.cgImage.map { UIImage(cgImage: $0, scale: 1, orientation: orientation) })
        let data = try #require(oriented.jpegData(compressionQuality: 0.9))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mosaic-recap-fixture-\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makeVideoFixture() async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mosaic-recap-video-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 320,
                AVVideoHeightKey: 240
            ]
        )
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: 320,
                kCVPixelBufferHeightKey as String: 240,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )
        try #require(writer.canAdd(input))
        writer.add(input)
        try #require(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData { await Task.yield() }
            let color: (red: UInt8, green: UInt8, blue: UInt8) = frame < 15
                ? (240, 28, 24)
                : (22, 42, 240)
            let buffer = try makePixelBuffer(width: 320, height: 240, color: color)
            try #require(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
        }
        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }
        try #require(writer.status == .completed)
        return url
    }

    private func makePixelBuffer(
        width: Int,
        height: Int,
        color: (red: UInt8, green: UInt8, blue: UInt8)
    ) throws -> CVPixelBuffer {
        var optionalBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary,
            &optionalBuffer
        )
        try #require(status == kCVReturnSuccess)
        let buffer = try #require(optionalBuffer)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let bytes = try #require(CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self))
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * rowBytes + x * 4
                bytes[offset] = color.blue
                bytes[offset + 1] = color.green
                bytes[offset + 2] = color.red
                bytes[offset + 3] = 255
            }
        }
        return buffer
    }

    private func rgba(_ image: CGImage, x: Int, y: Int) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let data = try #require(image.dataProvider?.data)
        let bytes = CFDataGetBytePtr(data)
        let offset = y * image.bytesPerRow + x * 4
        return (bytes![offset], bytes![offset + 1], bytes![offset + 2], bytes![offset + 3])
    }
}
