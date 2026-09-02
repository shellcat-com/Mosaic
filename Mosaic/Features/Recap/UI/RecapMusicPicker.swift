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
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MosaicTheme.muted)
                TextField("Search music", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(MosaicTheme.muted)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MosaicTheme.border, lineWidth: 1)
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
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(trackGradient(track))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: track.id == "none" ? "speaker.slash.fill" : "waveform")
                                .foregroundStyle(.white)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name)
                            .font(MosaicTheme.body(.semibold))
                        Text(track.id == "none" ? "Let the visuals breathe" : "\(track.artist) · \(track.mood) · \(time(track.duration))")
                            .font(MosaicTheme.caption())
                            .foregroundStyle(MosaicTheme.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    if track.id != "none" {
                        Button { preview.toggle(track) } label: {
                            Image(systemName: preview.playingID == track.id ? "pause.fill" : "play.fill")
                                .frame(width: 44, height: 44)
                        }
                        .disabled(track.bundledURL == nil)
                        .accessibilityLabel(preview.playingID == track.id ? "Pause \(track.name)" : "Preview \(track.name)")
                    }
                    Button {
                        preview.stop()
                        selection = track.id == "none" ? .silent : RecapAudioSelection(trackID: track.id, trimOffset: 0)
                    } label: {
                        Image(systemName: selection.trackID == (track.id == "none" ? nil : track.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(MosaicTheme.indigo)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Select \(track.name)")
                }
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .padding(.vertical, 8)
                .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            selection.trackID == (track.id == "none" ? nil : track.id) ? MosaicTheme.indigo : MosaicTheme.border,
                            lineWidth: selection.trackID == (track.id == "none" ? nil : track.id) ? 2 : 1
                        )
                }
            }
            if let selected = RecapMusicCatalog.track(id: selection.trackID), selected.id != "none" {
                RecapMusicTrimmer(track: selected, recapDuration: recapDuration, offset: $selection.trimOffset) { offset in
                    preview.play(selected, offset: offset)
                }
            }

            HStack {
                Button { showCredits = true } label: {
                    Label("Music credits", systemImage: "info.circle")
                }
                Spacer()
                if let selected = RecapMusicCatalog.track(id: selection.trackID), selected.id != "none" {
                    Button { toggleSaved(selected.id) } label: {
                        Label(savedIDs.contains(selected.id) ? "Saved" : "Save track",
                              systemImage: savedIDs.contains(selected.id) ? "bookmark.fill" : "bookmark")
                    }
                }
            }
            .font(MosaicTheme.caption(.semibold))
            .foregroundStyle(MosaicTheme.indigo)
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
