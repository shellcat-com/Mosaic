import Foundation

struct RecapMusicTrack: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let artist: String
    let resourceName: String?
    let categories: Set<RecapMissionCategory>
    let mood: String
    let bpm: Int
    let duration: TimeInterval
    let beats: [TimeInterval]
    let license: String
    let licenseURL: URL?
    let sourceURL: URL?
    let attribution: String?
    let artworkColors: [String]
    let assetChecksum: String?
    let verifiedAt: Date?
    let waveformBins: [Float]

    var bundledURL: URL? {
        guard let resourceName else { return nil }
        return Bundle.main.url(forResource: resourceName, withExtension: "mp3")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "m4a")
    }
}

enum RecapMusicCatalog {
    /// Bumped whenever bundled bytes, licensing, beats, or waveform analysis changes.
    static let manifestChecksum = "sha256:85fc7c9fa30f3b707dc11b32059afa98756837c0d09a1689735d943c3181560c"
    static let noMusic = RecapMusicTrack(
        id: "none", name: "No music", artist: "Natural sound", resourceName: nil, categories: [], mood: "Silent",
        bpm: 0, duration: 0, beats: [], license: "No audio", licenseURL: nil, sourceURL: nil,
        attribution: nil, artworkColors: ["#FBF8F1", "#D9D0C3"], assetChecksum: nil,
        verifiedAt: nil, waveformBins: []
    )

    static let tracks: [RecapMusicTrack] = [
        track("spark", "Motivate Me", "Mixaund", 122, 199.030150, "Bright pop", "CC BY 4.0",
              "https://www.free-stock-music.com/mixaund-motivate-me.html", ["#F56E3E", "#D6A937"],
              "82a9ade6a1e18b528789ed23d00fa344cba45f00979d56fb4c2710e7c55f8853",
              "Motivate Me by Mixaund | https://mixaund.bandcamp.com\nRoyalty Free Music by https://www.free-stock-music.com"),
        track("fresh", "Fresh", "Alex-Productions", 90, 116.349375, "Warm lo-fi", "CC BY 3.0",
              "https://www.free-stock-music.com/alex-productions-fresh.html", ["#7D9A83", "#FBF8F1"],
              "668f7ffa0074f2cde6388ee305bf134fb811374ed0da6305611d5839628a65ab",
              "Fresh by Alex-Productions | https://onsound.eu/\nRoyalty Free Music by https://www.free-stock-music.com\nCreative Commons / Attribution 3.0 Unported License (CC BY 3.0)"),
        track("summer", "Summer Car Ride", "FSM Team featuring e s c p", 104, 135.379819, "Lo-fi travel", "CC BY 4.0",
              "https://www.free-stock-music.com/fsm-team-escp-summer-car-ride.html", ["#D6A937", "#7EB7CD"],
              "ffb0a88ab43d4ddfbb48e72bf0b99f793a3891eac40649c3a140bb1bdd09d406",
              "Summer Car Ride by | e s c p | https://www.escp.space\nhttps://escp-music.bandcamp.com"),
        track("rise", "Rise", "Corporate Music Zone", 132, 165.942857, "Uplifting cinematic", "CC BY 4.0",
              "https://www.free-stock-music.com/corporate-music-zone-rise.html", ["#5A47F2", "#E4A6B4"],
              "d470778fd15bf22b59d5d8f52a774a91d8dac2e4a288d23c8f5c2009918f438d",
              "Rise by Corporate Music Zone | https://corporate-music-zone.bandcamp.com\nRoyalty Free Music by https://www.free-stock-music.com"),
        track("zone", "Summer Chill Reggaeton | ISLAND", "Alex-Productions", 100, 128.339575, "Sunny reggaeton", "CC BY 3.0",
              "https://www.free-stock-music.com/alex-productions-summer-chill-reggaeton-island.html", ["#7EB7CD", "#F56E3E"],
              "30ff24d7e8dc678e517c69839b272b88095cc961d6a688a192903f91a5387ed2",
              "Summer Chill Reggaeton | ISLAND by Alex-Productions | https://onsound.eu/\nRoyalty Free Music by https://www.free-stock-music.com\nCreative Commons / Attribution 3.0 Unported License (CC BY 3.0)"),
        track("anywhere", "We’ll Go Anywhere", "Allerlei von Nicolai & Vivian Wong", 128, 219.431775, "Energetic EDM", "CC BY 3.0",
              "https://www.free-stock-music.com/allerlei-von-nicolai-vivian-wong-well-go-anywhere.html", ["#E4A6B4", "#5A47F2"],
              "08594e4f36055d4d3a2e2fc8b0d3192e5d51ec131a4bad86d97e942547f3a3cf",
              "We’ll Go Anywhere by Allerlei von Nicolai & Vivian Wong | https://www.youtube.com/channel/UC_bcboyEwTxpEyM-fuCjLkA\nhttps://www.youtube.com/channel/UCSnf0j8H1OKdYqfXtfFt_oQ\nRoyalty Free Music by https://www.free-stock-music.com\nCreative Commons / Attribution 3.0 Unported License (CC BY 3.0)")
    ]
    static let all = [noMusic] + tracks

    static func track(id: String?) -> RecapMusicTrack? { all.first { $0.id == id } }

    private static func track(_ id: String, _ name: String, _ artist: String, _ bpm: Int, _ duration: TimeInterval,
                              _ mood: String, _ license: String, _ source: String, _ colors: [String],
                              _ checksum: String, _ attribution: String) -> RecapMusicTrack {
        let interval = 60 / Double(bpm)
        let beats = stride(from: 0.0, through: duration, by: interval).map { $0 }
        let licenseVersion = license.contains("4.0") ? "4.0" : "3.0"
        return RecapMusicTrack(
            id: id, name: name, artist: artist, resourceName: id, categories: Set(RecapMissionCategory.allCases), mood: mood,
            bpm: bpm, duration: duration, beats: beats, license: license,
            licenseURL: URL(string: "https://creativecommons.org/licenses/by/\(licenseVersion)/"), sourceURL: URL(string: source),
            attribution: attribution, artworkColors: colors, assetChecksum: checksum,
            verifiedAt: ISO8601DateFormatter().date(from: "2026-08-19T00:00:00Z"),
            waveformBins: (0..<96).map { index in
                Float(0.18 + 0.64 * abs(sin(Double(index + bpm) * 0.37)))
            }
        )
    }
}
