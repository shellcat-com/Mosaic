import Foundation
import SensitiveContentAnalysis

actor SensitivePhotoAnalyzer {
    private let analyzer = SCSensitivityAnalyzer()

    func isSensitive(_ jpeg: Data) async throws -> Bool {
        guard analyzer.analysisPolicy != .disabled else { return false }
        let directory = FileManager.default.temporaryDirectory.appending(path: "MosaicSafety", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(UUID().uuidString).jpg")
        try jpeg.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }
        return try await analyzer.analyzeImage(at: url).isSensitive
    }
}
