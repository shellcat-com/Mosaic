import CoreGraphics
import Foundation

struct RecapDetailsOptions: Codable, Hashable, Sendable {
    enum ReflectionDensity: String, Codable, Hashable, CaseIterable, Sendable { case fewer, balanced, more }
    var reflectionDensity: ReflectionDensity = .balanced
    var showAttribution = true
    var showMissionLabels = true
    var showImpactReceipt = true
}

struct RecapTimeline: Hashable, Sendable {
    enum Phase: String, Hashable, Sendable { case intro, memory, finalReveal, impactReceipt, outro }

    struct Segment: Identifiable, Hashable, Sendable {
        let id: String
        let phase: Phase
        let sourceIndex: Int?
        let start: TimeInterval
        let duration: TimeInterval
        var end: TimeInterval { start + duration }
    }

    struct FrameState: Hashable, Sendable {
        let time: TimeInterval
        let phase: Phase
        let segmentIndex: Int
        let sourceIndex: Int?
        let previousSourceIndex: Int?
        let progress: Double
        let transitionProgress: Double
        let scale: CGFloat
        let panX: CGFloat
        let tileProgress: Double
        let opacity: Double
    }

    let preset: RecapPreset
    let sources: [RecapSource]
    let segments: [Segment]
    let totalDuration: TimeInterval
    let reduceMotion: Bool

    static func build(
        sources: [RecapSource],
        preset: RecapPreset,
        audio: RecapAudioSelection,
        trackBeats: [TimeInterval],
        options: RecapDetailsOptions,
        reduceMotion: Bool
    ) -> RecapTimeline {
        let fairPool = Array(sources.prefix(24))
        let eligibleMemoryIndices = fairPool.indices.filter { index in
            switch fairPool[index].content {
            case .photo, .video: true
            case .reflection:
                switch options.reflectionDensity {
                case .fewer: index.isMultiple(of: 3)
                case .balanced, .more: true
                }
            case .tileOnly: false
            }
        }
        let selectedIndices = Array(eligibleMemoryIndices.prefix(preset.nominalClipCount))
        let adjustedBeats = RecapTimeline.adjustedBeats(trackBeats, trimOffset: audio.trimOffset)
        var segments: [Segment] = [.init(id: "intro", phase: .intro, sourceIndex: nil, start: 0, duration: 4)]
        var cursor: TimeInterval = 4

        for (montageIndex, sourceIndex) in selectedIndices.enumerated() {
            let duration: TimeInterval
            if montageIndex == selectedIndices.count - 1 {
                duration = preset.perMemory
            } else {
                let nominalEnd = 4 + Double(montageIndex + 1) * preset.perMemory
                let closest = adjustedBeats.min(by: { abs($0 - nominalEnd) < abs($1 - nominalEnd) })
                let tolerance = min(preset.perMemory * 0.5, 0.45)
                let proposedEnd = closest.map { abs($0 - nominalEnd) <= tolerance ? $0 : nominalEnd } ?? nominalEnd
                duration = min(max(proposedEnd - cursor, preset.perMemory * 0.6), preset.perMemory * 1.6)
            }
            segments.append(.init(id: "memory-\(sourceIndex)", phase: .memory, sourceIndex: sourceIndex, start: cursor, duration: duration))
            cursor += duration
        }

        segments.append(.init(id: "reveal", phase: .finalReveal, sourceIndex: nil, start: cursor, duration: 2.4))
        cursor += 2.4
        if options.showImpactReceipt {
            segments.append(.init(id: "impact", phase: .impactReceipt, sourceIndex: nil, start: cursor, duration: 2.6))
            cursor += 2.6
        }
        segments.append(.init(id: "outro", phase: .outro, sourceIndex: nil, start: cursor, duration: 2.1))
        cursor += 2.1
        return RecapTimeline(preset: preset, sources: fairPool, segments: segments, totalDuration: cursor, reduceMotion: reduceMotion)
    }

    func frame(at requestedTime: TimeInterval) -> FrameState {
        let time = min(max(requestedTime, 0), totalDuration)
        let segmentIndex = segments.lastIndex(where: { time >= $0.start }) ?? 0
        let segment = segments[segmentIndex]
        let raw = segment.duration > 0 ? min(max((time - segment.start) / segment.duration, 0), 1) : 1
        let eased = raw * raw * (3 - 2 * raw)
        let memorySegments = segments.filter { $0.phase == .memory }
        let motionIndex = segment.phase == .memory ? (memorySegments.firstIndex(where: { $0.id == segment.id }) ?? 0) : 0
        let pushIn = motionIndex.isMultiple(of: 2)
        let zoom = reduceMotion ? 1 : (pushIn ? 1 + (preset.kenBurnsZoom - 1) * eased : preset.kenBurnsZoom - (preset.kenBurnsZoom - 1) * eased)
        let pan = reduceMotion ? 0 : CGFloat(motionIndex.isMultiple(of: 2) ? -0.022 + 0.044 * eased : 0.022 - 0.044 * eased)
        let tileProgress: Double = switch segment.phase {
        case .intro: 0.15 * eased
        case .memory: 0.15 + 0.55 * (Double(motionIndex) + eased) / Double(max(memorySegments.count, 1))
        case .finalReveal: 0.7 + 0.3 * eased
        case .impactReceipt, .outro: 1
        }
        let opening = min(time / 0.4, 1)
        let closing = min((totalDuration - time) / 0.4, 1)
        let previousSourceIndex = segmentIndex > 0 ? segments[segmentIndex - 1].sourceIndex : nil
        let transitionDuration: TimeInterval
        if reduceMotion {
            transitionDuration = 0.22
        } else {
            transitionDuration = preset.transitionDuration
        }
        let transitionProgress = transitionDuration > 0
            ? min(max((time - segment.start) / transitionDuration, 0), 1)
            : 1
        return FrameState(time: time, phase: segment.phase, segmentIndex: segmentIndex, sourceIndex: segment.sourceIndex,
                          previousSourceIndex: previousSourceIndex, progress: eased, transitionProgress: transitionProgress,
                          scale: zoom, panX: pan, tileProgress: min(max(tileProgress, 0), 1), opacity: min(opening, closing))
    }

    static func adjustedBeats(_ beats: [TimeInterval], trimOffset: TimeInterval) -> [TimeInterval] {
        beats.filter { $0 >= trimOffset }.map { $0 - trimOffset }
    }
}
