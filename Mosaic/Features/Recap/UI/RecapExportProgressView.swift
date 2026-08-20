import SwiftUI

struct RecapExportProgressView: View {
    let progress: Double
    let status: RecapExportStatus
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(status == .muxing ? "Adding the music" : "Firing your recap")
                .font(MosaicTheme.display(29, weight: .semibold))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 5), count: 8), spacing: 5) {
                ForEach(0..<24, id: \.self) { index in
                    OrganicPanelShape(variant: .softRectangle)
                        .fill(Double(index) / 24 < progress ? MosaicTheme.indigo : MosaicTheme.claySurface)
                        .frame(width: 26, height: 26)
                }
            }
            ProgressView(value: progress).tint(MosaicTheme.indigo)
            Text("\(Int(progress * 100))%").font(.headline.monospacedDigit())
            Button("Cancel", role: .cancel, action: cancel).buttonStyle(SecondaryButtonStyle())
        }
        .padding(24).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .padding(24)
    }
}
