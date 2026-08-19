import SwiftUI

struct ArtworkSceneView: View {
    let scene: OnboardingScene
    let challenge: KindnessChallenge
    let onShowAttribution: () -> Void

    var body: some View {
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
                    .minimumScaleFactor(0.82)
                    .accessibilityAddTraits(.isHeader)

                Text(scene.supportingCopy)
                    .font(.subheadline)
                    .foregroundStyle(MosaicTheme.ink.opacity(0.64))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)

                ArtworkPanel(
                    scene: scene,
                    challenge: challenge,
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
    let challenge: KindnessChallenge
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
                    .frame(width: geometry.size.width, height: 350)
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
            .frame(width: geometry.size.width, height: 350)
        }
        .frame(height: 350)
        .clipShape(RoundedRectangle(cornerRadius: MosaicTheme.artworkCornerRadius, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button(action: onShowAttribution) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundStyle(MosaicTheme.ink.opacity(0.8))
                    .padding(8)
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
            ContributionStoryStrip()
        case .ceramicGrid:
            CeramicGridOverlay()
        case .passTheTile:
            PassTheTileOverlay()
        case .invitation:
            InvitationArtworkCard(challenge: challenge)
        }
    }

    private var cardFill: Color {
        reduceTransparency ? MosaicTheme.paper : MosaicTheme.paper.opacity(0.9)
    }
}

private struct ContributionStoryStrip: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 0) {
            StoryStat(value: "18", caption: "acts of care", tint: MosaicTheme.persimmon, motif: .heart)
            divider
            StoryStat(value: "equal", caption: "space for all", tint: MosaicTheme.sage, motif: .people)
            divider
            StoryStat(value: "5", caption: "days together", tint: MosaicTheme.indigo, motif: .sun)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 5)
        .background(reduceTransparency ? MosaicTheme.paper : MosaicTheme.paper.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MosaicTheme.ink.opacity(0.16), lineWidth: 1)
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
                .padding(3)
        }
        .shadow(color: MosaicTheme.ink.opacity(0.12), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle()
            .fill(MosaicTheme.clay.opacity(0.24))
            .frame(width: 1, height: 48)
    }
}

private struct StoryStat: View {
    enum Motif { case heart, people, sun }
    let value: String
    let caption: String
    let tint: Color
    let motif: Motif

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                motifView
                Text(value)
                    .font(MosaicTheme.display(value == "equal" ? 17 : 22, weight: .semibold))
            }
            .foregroundStyle(MosaicTheme.ink)

            Text(caption.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.65)
                .foregroundStyle(MosaicTheme.ink.opacity(0.52))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var motifView: some View {
        switch motif {
        case .heart:
            Image(systemName: "heart.fill")
                .font(.system(size: 12))
                .foregroundStyle(tint)
                .rotationEffect(.degrees(-7))
        case .people:
            ZStack {
                Circle().fill(tint).frame(width: 8, height: 8).offset(x: -3, y: -3)
                Circle().fill(tint.opacity(0.68)).frame(width: 8, height: 8).offset(x: 4, y: 2)
            }
            .frame(width: 15, height: 15)
        case .sun:
            Circle()
                .fill(tint)
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(MosaicTheme.paper, lineWidth: 2).padding(3))
        }
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
        .frame(height: 322)
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

private struct PassTheTileOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let points = [
                    CGPoint(x: size.width * 0.17, y: size.height * 0.24),
                    CGPoint(x: size.width * 0.48, y: size.height * 0.50),
                    CGPoint(x: size.width * 0.83, y: size.height * 0.76)
                ]
                var path = Path()
                path.move(to: points[0])
                path.addCurve(to: points[1], control1: CGPoint(x: size.width * 0.27, y: size.height * 0.17), control2: CGPoint(x: size.width * 0.34, y: size.height * 0.58))
                path.addCurve(to: points[2], control1: CGPoint(x: size.width * 0.61, y: size.height * 0.40), control2: CGPoint(x: size.width * 0.72, y: size.height * 0.82))
                context.stroke(path, with: .color(.white.opacity(0.76)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                context.stroke(path, with: .color(MosaicTheme.indigo.opacity(0.94)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [3, 7]))
            }

            ForEach(Array([0.17, 0.48, 0.83].enumerated()), id: \.offset) { index, x in
                Text("\(index + 1)")
                    .font(MosaicTheme.display(18, weight: .bold))
                    .foregroundStyle(index == 2 ? .white : MosaicTheme.ink)
                    .frame(width: 42, height: 42)
                    .background(index == 2 ? MosaicTheme.indigo : MosaicTheme.paper.opacity(0.94), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                    .overlay(Circle().stroke(MosaicTheme.indigo.opacity(0.7), lineWidth: 1).padding(-3))
                    .shadow(color: MosaicTheme.ink.opacity(0.18), radius: 7, y: 4)
                    .position(
                        x: geometry.size.width * x,
                        y: geometry.size.height * [0.24, 0.50, 0.76][index]
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 310)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Three equal tiles connected by an indigo Pass the Tile path")
    }
}

private struct InvitationArtworkCard: View {
    let challenge: KindnessChallenge

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 10) {
            Text("A MOSAIC INVITATION")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.7)
                .foregroundStyle(MosaicTheme.persimmon)

            Text(challenge.purpose)
                .font(MosaicTheme.display(19, weight: .medium))
                .foregroundStyle(MosaicTheme.ink)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(index == 3 ? MosaicTheme.persimmon : MosaicTheme.clay.opacity(0.32))
                        .frame(width: index == 3 ? 4 : 2.5, height: index == 3 ? 4 : 2.5)
                }
            }

            HStack(spacing: 6) {
                Text("PRIVATE CIRCLE")
                Text("·")
                Text("REVEALS \(challenge.revealDate.formatted(.dateTime.month(.abbreviated).day()).uppercased())")
            }
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(MosaicTheme.ink.opacity(0.68))
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(reduceTransparency ? MosaicTheme.paper : MosaicTheme.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MosaicTheme.ink.opacity(0.18), lineWidth: 1)
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
                .padding(3)
        }
        .shadow(color: MosaicTheme.ink.opacity(0.15), radius: 12, y: 6)
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
