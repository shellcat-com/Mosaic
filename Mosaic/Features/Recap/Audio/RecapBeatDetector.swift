import AVFoundation
import Accelerate
import Foundation

enum RecapBeatDetector {
    static func adjustedLoopingBeats(track: RecapMusicTrack, offset: TimeInterval, timelineDuration: TimeInterval) -> [TimeInterval] {
        guard track.duration > 0 else { return [] }
        let base = track.beats.filter { $0 >= offset }.map { $0 - offset }
        var result = base
        var loopStart = track.duration - offset
        while loopStart <= timelineDuration {
            result.append(contentsOf: track.beats.map { loopStart + $0 })
            loopStart += track.duration
        }
        return result.filter { $0 <= timelineDuration }.sorted()
    }

    static func waveform(url: URL, bins: Int = 160) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return [] }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false
        ])
        reader.add(output)
        reader.startReading()
        var samples: [Float] = []
        while let buffer = output.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buffer) {
            var length = 0
            var pointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer)
            if let pointer {
                let count = length / MemoryLayout<Float>.size
                samples.append(contentsOf: UnsafeBufferPointer(start: UnsafeRawPointer(pointer).assumingMemoryBound(to: Float.self), count: count))
            }
        }
        guard !samples.isEmpty else { return [] }
        let chunk = max(1, samples.count / bins)
        return stride(from: 0, to: samples.count, by: chunk).prefix(bins).map { start in
            let end = min(start + chunk, samples.count)
            var value: Float = 0
            vDSP_maxmgv(Array(samples[start..<end]), 1, &value, vDSP_Length(end - start))
            return min(value, 1)
        }
    }
}
