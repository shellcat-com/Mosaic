import AVFoundation
import CoreGraphics
import Foundation

enum RecapExportStatus: String, Codable, Hashable, Sendable {
    case queued, rendering, muxing, completedLocal, completedUploaded, failed, cancelled
}

struct RecapExportRequest: Codable, Hashable, Sendable {
    let meta: RecapMeta
    let sources: [RecapSource]
    let presetID: String
    let audio: RecapAudioSelection
    let options: RecapDetailsOptions
    let reduceMotion: Bool
    let rendererVersion: Int

    var preset: RecapPreset { RecapPresetCatalog.all.first { $0.id == presetID } ?? .init(
        id: RecapPresetCatalog.recommended.id, name: RecapPresetCatalog.recommended.name,
        description: RecapPresetCatalog.recommended.description, visualStyle: RecapPresetCatalog.recommended.visualStyle,
        minimumMemories: RecapPresetCatalog.recommended.minimumMemories,
        maximumMemories: RecapPresetCatalog.recommended.maximumMemories,
        nominalMontageDuration: RecapPresetCatalog.recommended.nominalMontageDuration,
        nominalClipCount: RecapPresetCatalog.recommended.nominalClipCount, perMemory: RecapPresetCatalog.recommended.perMemory,
        transition: RecapPresetCatalog.recommended.transition, transitionDuration: RecapPresetCatalog.recommended.transitionDuration,
        kenBurnsZoom: RecapPresetCatalog.recommended.kenBurnsZoom, layout: RecapPresetCatalog.recommended.layout,
        intro: RecapPresetCatalog.recommended.intro, chrome: RecapPresetCatalog.recommended.chrome,
        grade: RecapPresetCatalog.recommended.grade, defaultMusicID: RecapPresetCatalog.recommended.defaultMusicID
    ) }
}

enum RecapExportEvent: Sendable {
    case progress(Double, RecapExportStatus)
    case completed(URL)
}

enum RecapExportError: LocalizedError {
    case insufficientDiskSpace
    case cannotCreateWriter
    case cannotRenderFrame
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .insufficientDiskSpace: "Not enough free space to render this recap."
        case .cannotCreateWriter: "The video encoder could not be prepared."
        case .cannotRenderFrame: "A recap frame could not be rendered."
        case let .writerFailed(message): "The recap could not be exported: \(message)"
        }
    }
}

actor RecapComposer {
    private let width = 1080
    private let height = 1920
    private let fps: Int32 = 30
    private let maximumFrameCount: Int?

    /// A bounded frame count keeps codec integration tests deterministic without
    /// changing production exports, which always render the complete timeline.
    init(maximumFrameCount: Int? = nil) {
        self.maximumFrameCount = maximumFrameCount
    }

    func export(_ request: RecapExportRequest) -> AsyncThrowingStream<RecapExportEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = try await render(request, progress: { value, status in continuation.yield(.progress(value, status)) })
                    continuation.yield(.completed(url))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func render(_ request: RecapExportRequest, progress: @escaping @Sendable (Double, RecapExportStatus) -> Void) async throws -> URL {
        let music = RecapMusicCatalog.track(id: request.audio.trackID)
        let beats = music?.beats ?? []
        let timeline = RecapTimeline.build(sources: request.sources, preset: request.preset, audio: request.audio,
                                           trackBeats: beats, options: request.options, reduceMotion: request.reduceMotion)
        let estimate = Int64(timeline.totalDuration * 10_000_000 / 8 * 3) + 100_000_000
        let capacity = try FileManager.default.temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
        guard capacity > estimate else { throw RecapExportError.insufficientDiskSpace }

        let silentURL = FileManager.default.temporaryDirectory.appendingPathComponent("mosaic-silent-\(UUID().uuidString).mp4")
        let finalURL = FileManager.default.temporaryDirectory.appendingPathComponent("mosaic-recap-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: silentURL) }
        let writer = try AVAssetWriter(outputURL: silentURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 10_000_000, AVVideoExpectedSourceFrameRateKey: 30]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(input) else { throw RecapExportError.cannotCreateWriter }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        let completeFrameCount = Int(ceil(timeline.totalDuration * Double(fps)))
        let frameCount = min(completeFrameCount, maximumFrameCount ?? completeFrameCount)
        let renderedDuration = min(timeline.totalDuration, Double(frameCount) / Double(fps))
        let renderRequest = RecapRenderRequest(meta: request.meta, timeline: timeline, options: request.options, music: music)
        let frameRenderer = RecapFrameRenderer()

        for frame in 0..<frameCount {
            try Task.checkCancellation()
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(2))
                try Task.checkCancellation()
            }
            try Self.appendFrame(frame, fps: fps, width: width, height: height,
                                 request: renderRequest, renderer: frameRenderer, adaptor: adaptor, writer: writer)
            if frame.isMultiple(of: 6) { progress(Double(frame) / Double(frameCount) * 0.9, .rendering) }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw RecapExportError.writerFailed(writer.error?.localizedDescription ?? "Writer failed") }
        progress(0.92, .muxing)

        if let musicURL = music?.bundledURL {
            try await mux(videoURL: silentURL, audioURL: musicURL, selection: request.audio, duration: renderedDuration, outputURL: finalURL)
        } else {
            try FileManager.default.moveItem(at: silentURL, to: finalURL)
        }
        progress(1, .completedLocal)
        return finalURL
    }

    nonisolated private static func appendFrame(
        _ frame: Int,
        fps: Int32,
        width: Int,
        height: Int,
        request: RecapRenderRequest,
        renderer: RecapFrameRenderer,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        writer: AVAssetWriter
    ) throws {
        try autoreleasepool {
            guard let pool = adaptor.pixelBufferPool else { throw RecapExportError.cannotCreateWriter }
            var optionalBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
            guard let buffer = optionalBuffer else { throw RecapExportError.cannotRenderFrame }
            CVPixelBufferLockBaseAddress(buffer, [])
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            guard let base = CVPixelBufferGetBaseAddress(buffer),
                  let context = CGContext(data: base, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                throw RecapExportError.cannotRenderFrame
            }
            renderer.render(request: request, time: Double(frame) / Double(fps), in: context,
                            size: CGSize(width: width, height: height))
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps)) else {
                throw RecapExportError.writerFailed(writer.error?.localizedDescription ?? "Frame append failed")
            }
        }
    }

    private func mux(videoURL: URL, audioURL: URL, selection: RecapAudioSelection, duration: TimeInterval, outputURL: URL) async throws {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        guard let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first,
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
        try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600)), of: sourceVideo, at: .zero)
        guard let sourceAudio = try await audioAsset.loadTracks(withMediaType: .audio).first,
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
        let audioDuration = try await audioAsset.load(.duration).seconds
        var cursor: TimeInterval = 0
        var offset = min(selection.trimOffset, max(audioDuration - 0.05, 0))
        while cursor < duration {
            let available = audioDuration - offset
            let piece = min(available, duration - cursor)
            try audioTrack.insertTimeRange(CMTimeRange(start: CMTime(seconds: offset, preferredTimescale: 600), duration: CMTime(seconds: piece, preferredTimescale: 600)), of: sourceAudio, at: CMTime(seconds: cursor, preferredTimescale: 600))
            cursor += piece
            offset = 0
        }
        let parameters = AVMutableAudioMixInputParameters(track: audioTrack)
        parameters.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: min(0.7, duration / 2), preferredTimescale: 600)))
        parameters.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: CMTimeRange(start: CMTime(seconds: max(duration - 0.7, 0), preferredTimescale: 600), duration: CMTime(seconds: min(0.7, duration / 2), preferredTimescale: 600)))
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        try await writeMuxedComposition(composition, videoTrack: videoTrack, audioTrack: audioTrack, audioMix: mix,
                                        music: RecapMusicCatalog.track(id: selection.trackID), outputURL: outputURL)
    }

    private func writeMuxedComposition(
        _ composition: AVComposition,
        videoTrack: AVAssetTrack,
        audioTrack: AVAssetTrack,
        audioMix: AVAudioMix,
        music: RecapMusicTrack?,
        outputURL: URL
    ) async throws {
        let reader = try AVAssetReader(asset: composition)
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        videoOutput.alwaysCopiesSampleData = false
        let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: [audioTrack], audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        audioOutput.audioMix = audioMix
        guard reader.canAdd(videoOutput), reader.canAdd(audioOutput) else { throw RecapExportError.cannotCreateWriter }
        reader.add(videoOutput)
        reader.add(audioOutput)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoDescription = try await videoTrack.load(.formatDescriptions).first
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: videoDescription)
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192_000
        ])
        videoInput.expectsMediaDataInRealTime = false
        audioInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput), writer.canAdd(audioInput) else { throw RecapExportError.cannotCreateWriter }
        writer.add(videoInput)
        writer.add(audioInput)
        writer.metadata = exportMetadata(for: music)

        guard writer.startWriting(), reader.startReading() else {
            throw RecapExportError.writerFailed(writer.error?.localizedDescription ?? reader.error?.localizedDescription ?? "Mux could not start")
        }
        writer.startSession(atSourceTime: .zero)
        var videoFinished = false
        var audioFinished = false
        while !videoFinished || !audioFinished {
            try Task.checkCancellation()
            var advanced = false
            if !videoFinished, videoInput.isReadyForMoreMediaData {
                if let sample = videoOutput.copyNextSampleBuffer() {
                    guard videoInput.append(sample) else {
                        throw RecapExportError.writerFailed(writer.error?.localizedDescription ?? "Video mux failed")
                    }
                } else {
                    videoInput.markAsFinished()
                    videoFinished = true
                }
                advanced = true
            }
            if !audioFinished, audioInput.isReadyForMoreMediaData {
                if let sample = audioOutput.copyNextSampleBuffer() {
                    guard audioInput.append(sample) else {
                        throw RecapExportError.writerFailed(writer.error?.localizedDescription ?? "Audio encoding failed")
                    }
                } else {
                    audioInput.markAsFinished()
                    audioFinished = true
                }
                advanced = true
            }
            if !advanced { try await Task.sleep(for: .milliseconds(1)) }
        }
        await writer.finishWriting()
        guard writer.status == .completed, reader.status == .completed else {
            throw RecapExportError.writerFailed(writer.error?.localizedDescription ?? reader.error?.localizedDescription ?? "Mux failed")
        }
    }

    nonisolated private func exportMetadata(for music: RecapMusicTrack?) -> [AVMetadataItem] {
        func item(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
            let item = AVMutableMetadataItem()
            item.identifier = identifier
            item.value = value as NSString
            item.extendedLanguageTag = "und"
            return item
        }
        var result = [item(.commonIdentifierTitle, "Mosaic Community Recap")]
        if let music {
            result.append(item(.commonIdentifierArtist, music.artist))
            result.append(item(.commonIdentifierDescription,
                               [music.attribution, music.licenseURL?.absoluteString].compactMap { $0 }.joined(separator: "\n")))
            result.append(item(.commonIdentifierCopyrights, music.license))
        }
        return result
    }
}
