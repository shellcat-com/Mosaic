@preconcurrency import AVFoundation
import Foundation
import Testing
import UIKit
@testable import Mosaic

struct PhotoRecapTests {
    @Test
    func selectionPreservesOrderAndNeverDuplicates() {
        let first = UUID(), second = UUID(), third = UUID()
        var selection = PhotoRecapSelection()
        selection.toggle(first)
        selection.toggle(second)
        selection.toggle(third)
        #expect(selection.orderedPhotoIDs == [first, second, third])
        selection.toggle(second)
        selection.toggle(second)
        #expect(selection.orderedPhotoIDs == [first, third, second])
    }

    @Test
    func selectionCapsAtTwentyFour() {
        var selection = PhotoRecapSelection()
        for _ in 0..<30 { selection.toggle(UUID()) }
        #expect(selection.orderedPhotoIDs.count == 24)
    }

    @Test
    func rendererAcceptsOnlySelectedEventPhotosExactlyOnceInOrder() async throws {
        let eventID = UUID(), personID = UUID()
        let photos = (0..<3).map { index in
            EventPhoto(id: UUID(), mosaicID: eventID, photographerID: personID, photographerDisplayName: "Member",
                       filmLookID: .garden, capturedAt: Date(timeIntervalSince1970: Double(index)), state: .eligible,
                       storagePath: nil, localURL: URL(filePath: "/tmp/\(index).jpg"), signedURL: nil,
                       pixelWidth: 100, pixelHeight: 100, isMine: false)
        }
        var selection = PhotoRecapSelection()
        selection.toggle(photos[2].id)
        selection.toggle(photos[0].id)
        let project = PhotoRecapProject(mosaicID: eventID, selection: selection)
        let ordered = try await PhotoRecapRenderer().orderedPhotos(project: project, available: photos)
        #expect(ordered.map(\.id) == [photos[2].id, photos[0].id])
        #expect(Set(ordered.map(\.id)).count == ordered.count)
    }

    @Test
    func rendererRejectsEmptyAndMissingSelections() async {
        let renderer = PhotoRecapRenderer()
        await #expect(throws: PhotoRecapError.invalidSelection) {
            try await renderer.orderedPhotos(project: PhotoRecapProject(mosaicID: UUID()), available: [])
        }
        let missing = UUID()
        var selection = PhotoRecapSelection(); selection.toggle(missing)
        await #expect(throws: PhotoRecapError.missingPhoto(missing)) {
            try await renderer.orderedPhotos(project: PhotoRecapProject(mosaicID: UUID(), selection: selection), available: [])
        }
    }

    @Test
    func recapModelHasNoArtworkNoteIdentityOrStatisticsInputs() {
        let labels = Mirror(reflecting: PhotoRecapProject(mosaicID: UUID())).children.compactMap(\.label)
        #expect(labels == ["id", "mosaicID", "selection", "template", "music", "musicTrimOffset"])
    }

    @Test
    func templatesHaveDistinctTimingAndPhotoOnlyVisualRules() {
        let templates = PhotoRecapTemplate.allCases
        #expect(Set(templates.map(\.secondsPerPhoto)).count == templates.count)
        #expect(templates.allSatisfy { $0.secondsPerPhoto > 0 })
        #expect(templates.allSatisfy { !$0.detail.isEmpty })
    }

    @Test(.timeLimit(.minutes(3)))
    func twentyFourPhotoRecapRendersAtVerticalFullHDWithoutDroppingSelections() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Mosaic-Recap-Performance-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let eventID = UUID()
        var selection = PhotoRecapSelection()
        var photos: [EventPhoto] = []
        for index in 0..<24 {
            let photoID = UUID()
            let url = directory.appending(path: "\(index).jpg")
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 270, height: 480))
            let image = renderer.image { context in
                UIColor(hue: CGFloat(index) / 24, saturation: 0.48, brightness: 0.82, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 270, height: 480))
            }
            try #require(image.jpegData(compressionQuality: 0.72)).write(to: url)
            photos.append(EventPhoto(
                id: photoID, mosaicID: eventID, photographerID: UUID(), photographerDisplayName: "Member",
                filmLookID: .garden, capturedAt: Date(timeIntervalSince1970: Double(index)), state: .eligible,
                storagePath: nil, localURL: url, signedURL: nil,
                pixelWidth: 270, pixelHeight: 480, isMine: index.isMultiple(of: 2)
            ))
            selection.toggle(photoID)
        }

        let project = PhotoRecapProject(
            mosaicID: eventID,
            selection: selection,
            template: .kilnTape,
            music: .fresh
        )
        let output = try await PhotoRecapRenderer().render(project: project, available: photos) { _ in }
        defer { try? FileManager.default.removeItem(at: output) }

        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try #require(tracks.first)
        let size = try await track.load(.naturalSize)
        #expect(abs(duration - (24 * project.template.secondsPerPhoto)) < 0.2)
        #expect(abs(size.width) == PhotoRecapRenderer.size.width)
        #expect(abs(size.height) == PhotoRecapRenderer.size.height)
        #expect(selection.orderedPhotoIDs.count == 24)
    }
}
