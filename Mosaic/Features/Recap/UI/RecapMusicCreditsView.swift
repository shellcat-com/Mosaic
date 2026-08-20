import SwiftUI

struct RecapMusicCreditsView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(RecapMusicCatalog.tracks) { track in
                VStack(alignment: .leading, spacing: 7) {
                    Text(track.name).font(.headline)
                    Text(track.artist).foregroundStyle(MosaicTheme.muted)
                    Text(track.license).font(.caption.weight(.bold)).foregroundStyle(MosaicTheme.indigo)
                    if let attribution = track.attribution { Text(attribution).font(.caption).textSelection(.enabled) }
                    if let source = track.sourceURL { Link("Source and usage terms", destination: source).font(.caption) }
                    if let license = track.licenseURL { Link("License", destination: license).font(.caption) }
                }
                .padding(.vertical, 6)
            }
            .scrollContentBackground(.hidden).porcelainBackground()
            .navigationTitle("Music Credits")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
