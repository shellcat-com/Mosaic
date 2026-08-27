import Foundation

enum PhotoRecapTemplate: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case porcelainPrint
    case kilnTape
    case pocketKiln

    var id: String { rawValue }
    var title: String {
        switch self {
        case .porcelainPrint: "Porcelain Print"
        case .kilnTape: "Kiln Tape"
        case .pocketKiln: "Pocket Kiln"
        }
    }
    var detail: String {
        switch self {
        case .porcelainPrint: "Warm print borders · gentle fade · 2.4s"
        case .kilnTape: "Full bleed · warm grain · 1.8s"
        case .pocketKiln: "Dark matte · slow drift · 2.8s"
        }
    }
    var secondsPerPhoto: Double {
        switch self {
        case .porcelainPrint: 2.4
        case .kilnTape: 1.8
        case .pocketKiln: 2.8
        }
    }
}

enum PhotoRecapMusic: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case anywhere, fresh, rise, spark, summer, zone
    var id: String { rawValue }
    var title: String {
        switch self {
        case .anywhere: "We'll Go Anywhere"
        case .fresh: "Fresh"
        case .rise: "Rise"
        case .spark: "Motivate Me"
        case .summer: "Summer Car Ride"
        case .zone: "Summer Chill Reggaeton | ISLAND"
        }
    }
    var artist: String {
        switch self {
        case .anywhere: "Allerlei von Nicolai & Vivian Wong"
        case .fresh, .zone: "Alex-Productions"
        case .rise: "Corporate Music Zone"
        case .spark: "Mixaund"
        case .summer: "FSM Team featuring e s c p"
        }
    }
    var license: String {
        switch self {
        case .spark, .summer, .rise: "CC BY 4.0"
        case .anywhere, .fresh, .zone: "CC BY 3.0"
        }
    }
    var sourceURL: URL {
        let path = switch self {
        case .anywhere: "allerlei-von-nicolai-vivian-wong-well-go-anywhere.html"
        case .fresh: "alex-productions-fresh.html"
        case .rise: "corporate-music-zone-rise.html"
        case .spark: "mixaund-motivate-me.html"
        case .summer: "fsm-team-escp-summer-car-ride.html"
        case .zone: "alex-productions-summer-chill-reggaeton-island.html"
        }
        return URL(string: "https://www.free-stock-music.com/\(path)") ?? URL(fileURLWithPath: "/")
    }
}

struct PhotoRecapSelection: Codable, Hashable, Sendable {
    private(set) var orderedPhotoIDs: [UUID] = []

    mutating func toggle(_ id: UUID) {
        if let index = orderedPhotoIDs.firstIndex(of: id) {
            orderedPhotoIDs.remove(at: index)
        } else if orderedPhotoIDs.count < 24 {
            orderedPhotoIDs.append(id)
        }
    }

    mutating func move(from source: IndexSet, to destination: Int) {
        let moved = source.sorted().map { orderedPhotoIDs[$0] }
        for index in source.sorted(by: >) { orderedPhotoIDs.remove(at: index) }
        let removedBefore = source.filter { $0 < destination }.count
        orderedPhotoIDs.insert(contentsOf: moved, at: max(0, min(orderedPhotoIDs.count, destination - removedBefore)))
    }
}

struct PhotoRecapProject: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let mosaicID: UUID
    var selection: PhotoRecapSelection
    var template: PhotoRecapTemplate
    var music: PhotoRecapMusic
    var musicTrimOffset: TimeInterval

    init(id: UUID = UUID(), mosaicID: UUID, selection: PhotoRecapSelection = .init(), template: PhotoRecapTemplate = .porcelainPrint, music: PhotoRecapMusic = .anywhere, musicTrimOffset: TimeInterval = 0) {
        self.id = id
        self.mosaicID = mosaicID
        self.selection = selection
        self.template = template
        self.music = music
        self.musicTrimOffset = musicTrimOffset
    }
}
