@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import UIKit

enum PhotoRecapError: LocalizedError, Equatable {
    case invalidSelection
    case missingPhoto(UUID)
    case cannotCreateWriter
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .invalidSelection: "Choose between 1 and 24 photos."
        case .missingPhoto: "One selected photo is no longer available."
        case .cannotCreateWriter, .renderFailed: "Mosaic could not render this recap."
        }
    }
}

actor PhotoRecapRenderer {
    static let size = CGSize(width: 1080, height: 1920)
    static let framesPerSecond: Int32 = 30

    func orderedPhotos(project: PhotoRecapProject, available: [EventPhoto]) throws -> [EventPhoto] {
        guard (1...24).contains(project.selection.orderedPhotoIDs.count) else { throw PhotoRecapError.invalidSelection }
        let byID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        return try project.selection.orderedPhotoIDs.map { id in
            guard let photo = byID[id] else { throw PhotoRecapError.missingPhoto(id) }
            return photo
        }
    }

    func render(project: PhotoRecapProject, available: [EventPhoto], progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let photos = try orderedPhotos(project: project, available: available)
        let silentURL = FileManager.default.temporaryDirectory.appending(path: "Mosaic-Recap-\(project.id.uuidString)-silent.mp4")
        try? FileManager.default.removeItem(at: silentURL)
        let writer = try AVAssetWriter(outputURL: silentURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(Self.size.width), AVVideoHeightKey: Int(Self.size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(Self.size.width),
            kCVPixelBufferHeightKey as String: Int(Self.size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw PhotoRecapError.cannotCreateWriter }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? PhotoRecapError.cannotCreateWriter }
        writer.startSession(atSourceTime: .zero)

        let secondsPerPhoto = project.template.secondsPerPhoto
        let framesPerPhoto = Int(secondsPerPhoto * Double(Self.framesPerSecond))
        var frameNumber: Int64 = 0
        for (photoIndex, photo) in photos.enumerated() {
            guard let url = photo.displayURL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
                throw PhotoRecapError.missingPhoto(photo.id)
            }
            for localFrame in 0..<framesPerPhoto {
                while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(4)) }
                guard let pool = adaptor.pixelBufferPool else { throw PhotoRecapError.renderFailed }
                var optionalBuffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
                guard let buffer = optionalBuffer else { throw PhotoRecapError.renderFailed }
                draw(image: image, template: project.template, progress: Double(localFrame) / Double(framesPerPhoto), into: buffer)
                let time = CMTime(value: frameNumber, timescale: Self.framesPerSecond)
                guard adaptor.append(buffer, withPresentationTime: time) else { throw writer.error ?? PhotoRecapError.renderFailed }
                frameNumber += 1
            }
            progress(Double(photoIndex + 1) / Double(photos.count))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? PhotoRecapError.renderFailed }
        return try await addMusic(project.music, trimOffset: project.musicTrimOffset, to: silentURL, projectID: project.id)
    }

    private func draw(image: UIImage, template: PhotoRecapTemplate, progress: Double, into buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: base, width: Int(Self.size.width), height: Int(Self.size.height), bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return }
        let background: UIColor = switch template {
        case .porcelainPrint: UIColor(red: 0.98, green: 0.95, blue: 0.9, alpha: 1)
        case .kilnTape: UIColor(red: 0.04, green: 0.035, blue: 0.03, alpha: 1)
        case .pocketKiln: UIColor(red: 0.12, green: 0.13, blue: 0.12, alpha: 1)
        }
        context.setFillColor(background.cgColor)
        context.fill(CGRect(origin: .zero, size: Self.size))
        guard let cgImage = image.cgImage else { return }
        let contentRect: CGRect = switch template {
        case .porcelainPrint: CGRect(x: 68, y: 112, width: Self.size.width - 136, height: Self.size.height - 224)
        case .kilnTape: CGRect(origin: .zero, size: Self.size)
        case .pocketKiln: CGRect(x: 86, y: 168, width: Self.size.width - 172, height: Self.size.height - 336)
        }
        if template == .porcelainPrint {
            context.setShadow(offset: CGSize(width: 0, height: 16), blur: 26, color: UIColor.black.withAlphaComponent(0.22).cgColor)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(contentRect.insetBy(dx: -22, dy: -22))
            context.setShadow(offset: .zero, blur: 0)
        }
        let drift: CGFloat = switch template {
        case .porcelainPrint: 0.025
        case .kilnTape: 0.045
        case .pocketKiln: 0.018
        }
        let scale = max(contentRect.width / CGFloat(cgImage.width), contentRect.height / CGFloat(cgImage.height)) * CGFloat(1 + drift * progress)
        let drawSize = CGSize(width: CGFloat(cgImage.width) * scale, height: CGFloat(cgImage.height) * scale)
        let horizontalDrift = template == .pocketKiln ? CGFloat(progress - 0.5) * 18 : 0
        let rect = CGRect(x: contentRect.midX - drawSize.width / 2 + horizontalDrift,
                          y: contentRect.midY - drawSize.height / 2,
                          width: drawSize.width, height: drawSize.height)
        context.saveGState()
        context.clip(to: contentRect)
        let edge = 0.13
        let opacity = min(1, min(progress / edge, (1 - progress) / edge))
        context.setAlpha(CGFloat(max(0, opacity)))
        context.interpolationQuality = .high
        context.draw(cgImage, in: rect)
        if template == .kilnTape {
            context.setBlendMode(.softLight)
            context.setFillColor(UIColor(red: 0.95, green: 0.48, blue: 0.18, alpha: 0.18).cgColor)
            context.fill(contentRect)
        }
        context.restoreGState()
        if template == .pocketKiln {
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.34).cgColor)
            context.setLineWidth(2)
            context.stroke(contentRect)
        }
    }

    private func addMusic(_ music: PhotoRecapMusic, trimOffset: TimeInterval, to videoURL: URL, projectID: UUID) async throws -> URL {
        guard let musicURL = Bundle.main.url(forResource: music.rawValue, withExtension: "mp3", subdirectory: "Music")
                ?? Bundle.main.url(forResource: music.rawValue, withExtension: "mp3") else {
            throw PhotoRecapError.renderFailed
        }
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: musicURL)
        guard let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first,
              let sourceAudio = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            throw PhotoRecapError.renderFailed
        }
        let videoDuration = try await videoAsset.load(.duration)
        let audioDuration = try await audioAsset.load(.duration)
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw PhotoRecapError.renderFailed
        }
        try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: sourceVideo, at: .zero)
        let requestedOffset = CMTime(seconds: max(0, trimOffset), preferredTimescale: 600)
        var sourceStart = requestedOffset < audioDuration ? requestedOffset : .zero
        var destination = CMTime.zero
        while destination < videoDuration {
            let available = audioDuration - sourceStart
            let needed = videoDuration - destination
            let duration = min(available, needed)
            guard duration > .zero else { break }
            try audioTrack.insertTimeRange(CMTimeRange(start: sourceStart, duration: duration), of: sourceAudio, at: destination)
            destination = destination + duration
            sourceStart = .zero
        }
        let outputURL = FileManager.default.temporaryDirectory.appending(path: "Mosaic-Recap-\(projectID.uuidString).mp4")
        try? FileManager.default.removeItem(at: outputURL)
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw PhotoRecapError.renderFailed
        }
        try await exporter.export(to: outputURL, as: .mp4)
        try? FileManager.default.removeItem(at: videoURL)
        return outputURL
    }
}
