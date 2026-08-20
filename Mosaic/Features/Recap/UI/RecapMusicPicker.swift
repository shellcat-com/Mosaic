import AVFoundation
import Observation
import SwiftUI

struct RecapMusicPicker: View {
    @Binding var selection: RecapAudioSelection
    let recapDuration: TimeInterval
    @State private var search = ""
    @State private var preview = RecapMusicPreviewController()
    @State private var showCredits = false
    @State private var scope: Scope = .forYou
    @AppStorage("recap.savedMusicIDs") private var savedMusicIDs = ""

    enum Scope: String, CaseIterable { case forYou = "For You", all = "All", saved = "Saved" }

    private var tracks: [RecapMusicTrack] {
        let scoped: [RecapMusicTrack] = switch scope {
        case .forYou: [RecapMusicCatalog.noMusic] + Array(RecapMusicCatalog.tracks.prefix(4))
        case .all: RecapMusicCatalog.all
        case .saved: RecapMusicCatalog.tracks.filter { savedIDs.contains($0.id) }
        }
        return search.isEmpty ? scoped : scoped.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.artist.localizedCaseInsensitiveContains(search) || $0.mood.localizedCaseInsensitiveContains(search)
        }
    }

    private var savedIDs: Set<String> { Set(savedMusicIDs.split(separator: ",").map(String.init)) }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                TextField("Search music", text: $search).textFieldStyle(.roundedBorder)
                Button("Credits") { showCredits = true }.font(.subheadline.weight(.semibold))
            }
            Picker("Music collection", selection: $scope) {
                ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if tracks.isEmpty {
                ContentUnavailableView("No saved tracks", systemImage: "music.note.list",
                                       description: Text("Save a track from All to keep it close."))
            }
            ForEach(tracks) { track in
                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: 14).fill(trackGradient(track)).frame(width: 52, height: 52)
                        .overlay(Image(systemName: track.id == "none" ? "speaker.slash.fill" : "waveform").foregroundStyle(.white))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name).font(.headline)
                        Text(track.id == "none" ? "Let the visuals breathe" : "\(track.artist) · \(track.mood) · \(time(track.duration))")
                            .font(.caption).foregroundStyle(MosaicTheme.muted).lineLimit(1)
                    }
                    Spacer()
                    if track.id != "none" {
                        Button { preview.toggle(track) } label: { Image(systemName: preview.playingID == track.id ? "pause.circle.fill" : "play.circle") }.font(.title2)
                            .disabled(track.bundledURL == nil)
                        Button { toggleSaved(track.id) } label: {
                            Image(systemName: savedIDs.contains(track.id) ? "bookmark.fill" : "bookmark")
                        }
                        .foregroundStyle(savedIDs.contains(track.id) ? MosaicTheme.persimmon : MosaicTheme.muted)
                        .accessibilityLabel(savedIDs.contains(track.id) ? "Remove from saved" : "Save track")
                    }
                    Button {
                        preview.stop()
                        selection = track.id == "none" ? .silent : RecapAudioSelection(trackID: track.id, trimOffset: 0)
                    } label: {
                        Image(systemName: selection.trackID == (track.id == "none" ? nil : track.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(MosaicTheme.indigo)
                    }
                }
                .padding(12).background(MosaicTheme.paper, in: OrganicPanelShape(variant: .softRectangle))
            }
            if let selected = RecapMusicCatalog.track(id: selection.trackID), selected.id != "none" {
                RecapMusicTrimmer(track: selected, recapDuration: recapDuration, offset: $selection.trimOffset) { offset in
                    preview.play(selected, offset: offset)
                }
            }
        }
        .sheet(isPresented: $showCredits) { RecapMusicCreditsView() }
        .onDisappear { preview.stop() }
    }

    private func trackGradient(_ track: RecapMusicTrack) -> LinearGradient {
        let colors = track.artworkColors.compactMap { Color(hexString: $0) }
        return LinearGradient(colors: colors.isEmpty ? [MosaicTheme.clay, MosaicTheme.indigo] : colors,
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private func time(_ value: TimeInterval) -> String { String(format: "%d:%02d", Int(value) / 60, Int(value) % 60) }

    private func toggleSaved(_ id: String) {
        var values = savedIDs
        if !values.insert(id).inserted { values.remove(id) }
        savedMusicIDs = values.sorted().joined(separator: ",")
    }
}

@MainActor
@Observable
private final class RecapMusicPreviewController {
    private var player: AVPlayer?
    var playingID: String?

    func toggle(_ track: RecapMusicTrack) {
        if playingID == track.id { stop(); return }
        play(track, offset: 0)
    }

    func play(_ track: RecapMusicTrack, offset: TimeInterval) {
        guard let url = track.bundledURL else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = AVPlayer(url: url)
        player?.seek(to: CMTime(seconds: offset, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        player?.play()
        playingID = track.id
    }
    func stop() {
        player?.pause(); player = nil; playingID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private extension Color {
    init?(hexString: String) {
        let value = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let number = UInt64(value, radix: 16), value.count == 6 else { return nil }
        self.init(red: Double((number >> 16) & 0xff) / 255, green: Double((number >> 8) & 0xff) / 255, blue: Double(number & 0xff) / 255)
    }
}
