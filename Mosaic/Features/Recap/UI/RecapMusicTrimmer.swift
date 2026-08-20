import SwiftUI

struct RecapMusicTrimmer: View {
    let track: RecapMusicTrack
    let recapDuration: TimeInterval
    @Binding var offset: TimeInterval
    var preview: (TimeInterval) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Choose the opening beat").font(.headline)
                Spacer()
                Text(time(offset)).font(.caption.monospacedDigit()).foregroundStyle(MosaicTheme.muted)
            }
            GeometryReader { proxy in
                Canvas { context, size in
                    let bins = track.waveformBins.isEmpty ? [Float](repeating: 0.5, count: 68) : track.waveformBins
                    let bars = bins.count
                    for index in 0..<bars {
                        let height = max(5, size.height * CGFloat(bins[index]))
                        let x = CGFloat(index) / CGFloat(bars - 1) * size.width
                        context.fill(Path(roundedRect: CGRect(x: x, y: (size.height - height) / 2, width: 2.5, height: height), cornerRadius: 2),
                                     with: .color(MosaicTheme.indigo.opacity(0.65)))
                    }
                    let width = max(34, size.width * min(recapDuration / max(track.duration, 1), 1))
                    let maxOffset = max(track.duration - recapDuration, 0)
                    let x = maxOffset > 0 ? CGFloat(offset / maxOffset) * (size.width - width) : 0
                    context.stroke(Path(roundedRect: CGRect(x: x, y: 1, width: width, height: size.height - 2), cornerRadius: 12),
                                   with: .color(MosaicTheme.gold), lineWidth: 4)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let maximum = max(track.duration - recapDuration, 0)
                    let raw = Double(min(max(value.location.x / max(proxy.size.width, 1), 0), 1)) * maximum
                    offset = nearestBeat(to: raw)
                })
            }
            .frame(height: 70)
            Button {
                preview(offset)
            } label: {
                Label("Preview from \(time(offset))", systemImage: "play.fill")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MosaicTheme.indigo)
            Text("The gold window is the part used by this recap. It loops when the story is longer than the track.")
                .font(.caption).foregroundStyle(MosaicTheme.muted)
        }
        .padding(14).background(MosaicTheme.paper, in: OrganicPanelShape(variant: .softRectangle))
    }

    private func nearestBeat(to value: TimeInterval) -> TimeInterval {
        track.beats.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
    }
    private func time(_ value: TimeInterval) -> String { String(format: "%d:%02d", Int(value) / 60, Int(value) % 60) }
}
