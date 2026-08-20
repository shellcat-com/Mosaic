import SwiftUI

struct ArtworkSceneView: View {
    let scene: OnboardingScene
    let onShowAttribution: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 14) {
                    Label(scene.eyebrow, systemImage: "sparkle")
                        .font(MosaicTheme.caption())
                        .foregroundStyle(MosaicTheme.ink.opacity(0.72))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(MosaicTheme.paper.opacity(0.94), in: Capsule())
                        .overlay {
                            Capsule().stroke(MosaicTheme.clay.opacity(0.35), lineWidth: 1)
                        }

                    headline
                        .font(MosaicTheme.display(36, weight: .medium))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 350)
                        .minimumScaleFactor(0.78)
                        .accessibilityAddTraits(.isHeader)

                    Text(scene.supportingCopy)
                        .font(.subheadline)
                        .foregroundStyle(MosaicTheme.ink.opacity(0.64))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)

                    ArtworkPanel(
                        scene: scene,
                        height: min(350, max(250, geometry.size.height * 0.48)),
                        onShowAttribution: onShowAttribution
                    )
                    .padding(.top, 4)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var headline: Text {
        Text(scene.headlineLead)
            .foregroundStyle(MosaicTheme.ink)
        + Text(scene.headlineAccent)
            .foregroundStyle(MosaicTheme.persimmon)
            .italic()
    }
}

private struct ArtworkPanel: View {
    let scene: OnboardingScene
    let height: CGFloat
    let onShowAttribution: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var artworkScale = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Image(scene.artwork.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: height, alignment: scene.imageAlignment)
                    .scaleEffect(artworkScale ? 1.035 : 1)
                    .clipped()

                LinearGradient(
                    colors: [MosaicTheme.editorialScrim.opacity(0.66), .clear, MosaicTheme.ink.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                overlay
                    .padding(14)
            }
            .frame(width: geometry.size.width, height: height)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: MosaicTheme.artworkCornerRadius, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button(action: onShowAttribution) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundStyle(MosaicTheme.ink.opacity(0.8))
                    .frame(width: MosaicTheme.minimumHitTarget, height: MosaicTheme.minimumHitTarget)
                    .background(cardFill, in: Circle())
            }
            .accessibilityLabel("Artwork details for \(scene.artwork.title)")
            .padding(10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MosaicTheme.artworkCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: MosaicTheme.ink.opacity(0.14), radius: 18, y: 9)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(scene.artwork.accessibilityDescription)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                artworkScale = true
            }
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch scene.overlay {
        case .equalContribution:
            CeramicGridOverlay()
        case .privacyChoice:
            PrivacyArtworkOverlay()
        case .sharedReveal:
            SharedRevealOverlay()
        }
    }

    private var cardFill: Color {
        reduceTransparency ? MosaicTheme.paper : MosaicTheme.paper.opacity(0.9)
    }
}

private struct PrivacyArtworkOverlay: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 9) {
            privacyRow(
                icon: "lock.shield.fill",
                title: "Evidence",
                value: "Organizer only",
                tint: MosaicTheme.indigo
            )
            privacyRow(
                icon: "heart.text.square.fill",
                title: "Memory + name",
                value: "Your choice",
                tint: MosaicTheme.sage
            )
        }
        .padding(13)
        .background(
            reduceTransparency ? MosaicTheme.paper : MosaicTheme.paper.opacity(0.93),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: MosaicTheme.ink.opacity(0.14), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Evidence is visible only to organizers. Sharing a memory and name is your choice.")
    }

    private func privacyRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text(value).font(.footnote.weight(.semibold)).foregroundStyle(MosaicTheme.muted)
        }
    }
}

private struct SharedRevealOverlay: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill([MosaicTheme.persimmon, MosaicTheme.sage, MosaicTheme.indigo][index])
                        .frame(width: 29, height: 29)
                        .rotationEffect(.degrees(Double(index - 1) * 4))
                }
            }
            Image(systemName: "arrow.right")
                .font(.headline.weight(.bold))
                .foregroundStyle(MosaicTheme.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Label("SHARED REVEAL", systemImage: "sparkles")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(MosaicTheme.persimmon)
                Text("Every verified tile belongs")
                    .font(MosaicTheme.display(17, weight: .semibold))
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
        .frame(maxWidth: .infinity)
        .background(
            reduceTransparency ? MosaicTheme.paper : MosaicTheme.paper.opacity(0.93),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: MosaicTheme.ink.opacity(0.14), radius: 10, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Verified equal tiles open together into the shared reveal")
    }
}

private struct CeramicGridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let thirdWidth = size.width / 3
                let thirdHeight = size.height / 3
                for index in 1...2 {
                    var vertical = Path()
                    let x = thirdWidth * CGFloat(index)
                    vertical.move(to: CGPoint(x: x - 1, y: 0))
                    vertical.addQuadCurve(to: CGPoint(x: x + 1, y: size.height), control: CGPoint(x: x + (index == 1 ? 2 : -2), y: size.height * 0.52))
                    context.stroke(vertical, with: .color(.white.opacity(0.84)), lineWidth: 2)
                    context.stroke(vertical.offsetBy(dx: 2, dy: 0), with: .color(MosaicTheme.ink.opacity(0.12)), lineWidth: 0.8)

                    var horizontal = Path()
                    let y = thirdHeight * CGFloat(index)
                    horizontal.move(to: CGPoint(x: 0, y: y + 1))
                    horizontal.addQuadCurve(to: CGPoint(x: size.width, y: y - 1), control: CGPoint(x: size.width * 0.5, y: y + (index == 1 ? -2 : 2)))
                    context.stroke(horizontal, with: .color(.white.opacity(0.84)), lineWidth: 2)
                    context.stroke(horizontal.offsetBy(dx: 0, dy: 2), with: .color(MosaicTheme.ink.opacity(0.12)), lineWidth: 0.8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            KindnessSeal()
                .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(MosaicTheme.ink.opacity(0.025), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The painting divided into nine equal ceramic tile positions")
    }
}

private struct KindnessSeal: View {
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MosaicTheme.paper.opacity(0.94))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-2))
                    .shadow(color: MosaicTheme.ink.opacity(0.18), radius: 8, y: 4)
                HStack(spacing: 2) {
                    ForEach(Array([MosaicTheme.persimmon, MosaicTheme.sage, MosaicTheme.indigo].enumerated()), id: \.offset) { _, color in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: 9, height: 9)
                            .rotationEffect(.degrees(45))
                    }
                }
            }
            Text("YOUR MARK")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white)
                .shadow(color: MosaicTheme.ink.opacity(0.7), radius: 2)
        }
    }
}

struct ArtworkAttributionSheet: View {
    let artwork: ArtworkAttribution

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(artwork.assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .accessibilityLabel(artwork.accessibilityDescription)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(artwork.title)
                            .font(MosaicTheme.display(28, weight: .semibold))
                        Text("\(artwork.artist), \(artwork.date)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Label("CC0 Public Domain Designation", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MosaicTheme.sage)

                    Text(artwork.requestedCredit)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Link(destination: artwork.sourceURL) {
                        Label("View artwork at the Art Institute", systemImage: "arrow.up.right")
                            .font(.headline)
                    }
                }
                .padding(22)
            }
            .porcelainBackground()
            .navigationTitle("Artwork details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
