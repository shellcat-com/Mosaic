import SwiftUI

/// A production review surface for comparing the entire published catalog in identical crops.
/// It makes repeated silhouettes, weak sealed states, and contrast regressions visible before release.
struct KinderThemeContactSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: KinderArtworkPhase = .invitation
    @State private var paletteID: KinderThemePaletteID = .signature

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 18) {
                MosaicSectionHeader(
                    title: "Catalog review",
                    eyebrow: "120 published artworks",
                    icon: .mosaic
                )

                Picker("Artwork state", selection: $phase) {
                    Text("Cover").tag(KinderArtworkPhase.invitation)
                    Text("Sealed").tag(KinderArtworkPhase.sealed)
                    Text("Reveal").tag(KinderArtworkPhase.reveal)
                }
                .pickerStyle(.segmented)

                Picker("Finish", selection: $paletteID) {
                    ForEach(KinderThemePaletteID.allCases) { palette in
                        Text(palette.title).tag(palette)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(KinderThemeCollection.allCases) { collection in
                    VStack(alignment: .leading, spacing: 12) {
                        Label(collection.title, systemImage: collection.symbol)
                            .font(MosaicTheme.display(22, weight: .semibold))
                            .foregroundStyle(MosaicTheme.ink)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(KinderThemeCatalog.all.filter { $0.collection == collection }) { theme in
                                VStack(alignment: .leading, spacing: 7) {
                                    KinderArtworkView(
                                        selection: ThemeSelection(
                                            themeID: theme.id,
                                            paletteID: paletteID,
                                            seed: theme.seed,
                                            revision: KinderThemeCatalog.revision
                                        ),
                                        phase: phase,
                                        revealProgress: 1,
                                        cornerRadius: 18
                                    )
                                    .frame(height: 148)
                                    Text(theme.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MosaicTheme.ink)
                                        .lineLimit(2)
                                    Text(theme.material.rawValue.replacingOccurrences(of: "_", with: " "))
                                        .font(.caption2)
                                        .foregroundStyle(MosaicTheme.muted)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Artwork contact sheet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
