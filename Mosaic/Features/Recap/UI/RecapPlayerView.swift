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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black)
            if let renderedImage {
                Image(decorative: renderedImage, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text("Preparing preview…")
                        .font(MosaicTheme.caption(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            Button(action: onTogglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
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
