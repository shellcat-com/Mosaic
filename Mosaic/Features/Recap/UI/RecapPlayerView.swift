import SwiftUI

struct RecapPlayerView: View {
    let request: RecapRenderRequest?
    @Binding var currentTime: TimeInterval
    let isPlaying: Bool
    let onTogglePlayback: () -> Void

    @State private var renderedImage: CGImage?
    private let renderer = RecapFrameRenderer()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(LinearGradient(colors: [MosaicTheme.claySurface, MosaicTheme.paper], startPoint: .top, endPoint: .bottom))
                .shadow(color: MosaicTheme.gold.opacity(0.25), radius: 28, y: 14)
            if let renderedImage {
                Image(decorative: renderedImage, scale: 1)
                    .resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(10)
            } else {
                VStack(spacing: 14) {
                    ProgressView().tint(MosaicTheme.indigo)
                    Text("Developing your recap…").font(MosaicTheme.body(.semibold))
                }
            }
            Button(action: onTogglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2).foregroundStyle(.white)
                    .frame(width: 54, height: 54).background(.black.opacity(0.55), in: Circle())
            }
            .accessibilityLabel(isPlaying ? "Pause recap" : "Play recap")
        }
        .aspectRatio(9 / 16, contentMode: .fit)
        .task(id: renderID) { await renderFrame() }
    }

    private var renderID: String { "\(request?.timeline.preset.id ?? "none")-\(Int(currentTime * 30))" }

    private func renderFrame() async {
        guard let request else { return }
        let time = currentTime
        let renderer = renderer
        renderedImage = await Task.detached(priority: .userInitiated) {
            renderer.makeImage(request: request, time: time, size: CGSize(width: 360, height: 640))
        }.value
    }
}
