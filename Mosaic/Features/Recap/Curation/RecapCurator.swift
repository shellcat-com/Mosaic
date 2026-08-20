import Accelerate
import CoreGraphics
import Foundation

enum RecapCurator {
    static func curate(_ input: [RecapSource], limit: Int = 24) -> [RecapSource] {
        let eligible = input.filter { $0.eligibility.isEligible }
        let deduplicated = collapseDuplicates(eligible)
        let blurFiltered = removeClearlyBlurryAlternatives(deduplicated)
        let grouped = Dictionary(grouping: blurFiltered, by: \.participantID)
        let participantIDs = grouped.keys.sorted { $0.uuidString < $1.uuidString }
        var queues = participantIDs.reduce(into: [UUID: [RecapSource]]()) { result, id in
            result[id] = grouped[id, default: []].sorted {
                if $0.categoryKey != $1.categoryKey { return $0.categoryKey < $1.categoryKey }
                if $0.acceptedAt != $1.acceptedAt { return $0.acceptedAt < $1.acceptedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        }
        var result: [RecapSource] = []
        var categoryCounts: [String: Int] = [:]

        // Give every participant up to two turns before anybody receives a third.
        // Within each turn prefer the least represented mission category.
        for _ in 0..<2 {
            for participant in participantIDs where result.count < limit {
                guard let queue = queues[participant], !queue.isEmpty else { continue }
                let index = queue.indices.min { left, right in
                    let leftCount = categoryCounts[queue[left].categoryKey, default: 0]
                    let rightCount = categoryCounts[queue[right].categoryKey, default: 0]
                    if leftCount != rightCount { return leftCount < rightCount }
                    if queue[left].acceptedAt != queue[right].acceptedAt { return queue[left].acceptedAt < queue[right].acceptedAt }
                    return queue[left].id.uuidString < queue[right].id.uuidString
                } ?? queue.startIndex
                let selected = queue[index]
                result.append(selected)
                categoryCounts[selected.categoryKey, default: 0] += 1
                queues[participant]?.remove(at: index)
            }
        }

        while result.count < limit {
            var added = false
            for participant in participantIDs where result.count < limit {
                guard let next = queues[participant]?.first else { continue }
                result.append(next)
                categoryCounts[next.categoryKey, default: 0] += 1
                queues[participant]?.removeFirst()
                added = true
            }
            if !added { break }
        }
        return result
    }

    private static func collapseDuplicates(_ sources: [RecapSource]) -> [RecapSource] {
        let ordered = sources.sorted {
            if $0.acceptedAt != $1.acceptedAt { return $0.acceptedAt < $1.acceptedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        var kept: [RecapSource] = []
        for source in ordered {
            let duplicate = kept.last.map { previous in
                guard previous.participantID == source.participantID,
                      let first = previous.perceptualHash, let second = source.perceptualHash else { return false }
                return (first ^ second).nonzeroBitCount <= 6
            } ?? false
            if !duplicate { kept.append(source) }
        }
        return kept
    }

    private static func removeClearlyBlurryAlternatives(_ sources: [RecapSource]) -> [RecapSource] {
        let grouped = Dictionary(grouping: sources) { "\($0.participantID.uuidString)-\($0.categoryKey)" }
        return sources.filter { source in
            guard let score = source.blurScore, score < 75,
                  let alternatives = grouped["\(source.participantID.uuidString)-\(source.categoryKey)"],
                  alternatives.count > 1 else { return true }
            return !alternatives.contains { ($0.blurScore ?? 0) >= max(150, score * 2) }
        }
    }

    static func averageHash(_ image: CGImage) -> UInt64? {
        guard let bytes = grayscale(image, width: 8, height: 8) else { return nil }
        let average = bytes.reduce(0) { $0 + Int($1) } / bytes.count
        return bytes.enumerated().reduce(UInt64(0)) { hash, pair in
            pair.element >= average ? hash | (UInt64(1) << UInt64(pair.offset)) : hash
        }
    }

    static func laplacianVariance(_ image: CGImage) -> Double? {
        guard let pixels = grayscale(image, width: 64, height: 64) else { return nil }
        var values: [Double] = []
        values.reserveCapacity(62 * 62)
        for y in 1..<63 {
            for x in 1..<63 {
                let center = Double(pixels[y * 64 + x]) * -4
                let value = center + Double(pixels[(y - 1) * 64 + x]) + Double(pixels[(y + 1) * 64 + x])
                    + Double(pixels[y * 64 + x - 1]) + Double(pixels[y * 64 + x + 1])
                values.append(value)
            }
        }
        guard !values.isEmpty else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        return values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
    }

    private static func grayscale(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }
}

private extension RecapSource {
    var categoryKey: String { category?.rawValue ?? "shared-moment" }
}
