import SwiftUI

struct TilePlacementView: View {
    @Environment(AppStore.self) private var store
    @Environment(MosaicRouter.self) private var router
    let contribution: TileContribution
    @AppStorage(ContextualEducationProgress.passTheTileShownKey) private var hasShownPassTheTile = false

    @State private var placed = false
    @State private var isPlacing = false
    @State private var showPassTheTile = false
    @State private var dragOffset: CGSize = .zero
    @State private var boardFrame: CGRect = .zero
    @State private var tileFrame: CGRect = .zero
    @State private var isMagneticallyAligned = false
    @State private var alignmentTick = 0
    @State private var finalPosition: Int?

    private var predictedPosition: Int? {
        guard let sealed = store.challenge.sealedArtwork else { return nil }
        return BoardGeometry(side: sealed.boardSide).firstOpenPosition(
            occupied: Set(store.challenge.contributions.compactMap(\.tilePosition))
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            MosaicProgressRail(current: 5, total: 5, tint: MosaicTheme.sage)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            VStack(spacing: 8) {
                Text(placed ? "Your tile has a place" : "Place your tile")
                    .font(MosaicTheme.display(34, weight: .semibold))
                Text(placed
                     ? "Your kindness is now part of the shared Mosaic."
                     : "Drag into the glowing space, or use the button below.")
                    .font(MosaicTheme.body())
                    .foregroundStyle(MosaicTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            placementStage

            if placed {
                completionActions
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Button {
                    Task { await placeTile() }
                } label: {
                    if isPlacing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Place my tile")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isPlacing)
                .accessibilityHint("Places your earned tile in the first available board position")
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 20)
        .porcelainBackground()
        .coordinateSpace(name: "tile-placement")
        .navigationBarBackButtonHidden(placed)
        .sensoryFeedback(.alignment, trigger: alignmentTick)
        .sensoryFeedback(.success, trigger: placed)
        .fullScreenCover(isPresented: $showPassTheTile) {
            PassTheTileView(contribution: contribution)
                .environment(store)
                .environment(router)
        }
    }

    private var placementStage: some View {
        VStack(spacing: 16) {
            if !placed {
                CeramicTile(
                    category: contribution.mission.category,
                    emotion: contribution.emotion,
                    evidence: contribution.evidence,
                    isRevived: contribution.isRevived,
                    size: 96
                )
                .offset(dragOffset)
                .scaleEffect(isMagneticallyAligned ? 0.72 : 1)
                .shadow(color: MosaicTheme.indigo.opacity(isMagneticallyAligned ? 0.3 : 0), radius: 12)
                .gesture(dragGesture)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named("tile-placement"))
                } action: { tileFrame = $0 }
                .accessibilityLabel("Earned \(contribution.emotion.title) tile")
                .accessibilityHint("Drag to the open position on the board")
                .accessibilityAction(named: "Place tile") {
                    Task { await placeTile() }
                }
                .zIndex(3)
            }

            MosaicBoardView(
                challenge: store.challenge,
                mode: .sealed,
                predictedPosition: placed ? nil : predictedPosition,
                emphasizedPosition: finalPosition
            )
            .frame(maxWidth: 320)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named("tile-placement"))
            } action: { boardFrame = $0 }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: dragOffset)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("tile-placement"))
            .onChanged { value in
                guard !isPlacing else { return }
                let aligned = boardFrame.insetBy(dx: -16, dy: -16).contains(value.location)
                if aligned != isMagneticallyAligned {
                    isMagneticallyAligned = aligned
                    if aligned { alignmentTick += 1 }
                }
                if aligned, let target = targetCenter {
                    let restingCenter = CGPoint(
                        x: tileFrame.midX - dragOffset.width,
                        y: tileFrame.midY - dragOffset.height
                    )
                    dragOffset = CGSize(
                        width: target.x - restingCenter.x,
                        height: target.y - restingCenter.y
                    )
                } else {
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                let shouldPlace = boardFrame.insetBy(dx: -16, dy: -16).contains(value.location)
                if shouldPlace {
                    Task { await placeTile() }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        dragOffset = .zero
                        isMagneticallyAligned = false
                    }
                }
            }
    }

    private var targetCenter: CGPoint? {
        guard let sealed = store.challenge.sealedArtwork, let predictedPosition else { return nil }
        let geometry = BoardGeometry(side: sealed.boardSide)
        let frame = geometry.tileFrame(for: predictedPosition, in: boardFrame.insetBy(dx: 4, dy: 4), spacing: 4)
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private var completionActions: some View {
        VStack(spacing: 12) {
            Button {
                router.finishFlow(at: .groups)
            } label: {
                Label("View my Mosaic", systemImage: "square.grid.2x2.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.sage))

            Button {
                router.finishFlow(at: .groups)
            } label: {
                Label("Back to home", systemImage: "house.fill")
            }
            .buttonStyle(SecondaryButtonStyle(color: MosaicTheme.indigo))

            if !hasShownPassTheTile {
                Button {
                    hasShownPassTheTile = true
                    showPassTheTile = true
                } label: {
                    Label("Pass the Tile", systemImage: "link")
                }
                .buttonStyle(.plain)
                .font(MosaicTheme.body(.semibold))
                .foregroundStyle(MosaicTheme.indigo)
                .frame(maxWidth: .infinity, minHeight: MosaicTheme.minimumHitTarget)
            }
        }
        .padding(.horizontal, 20)
    }

    private func placeTile() async {
        guard !isPlacing else { return }
        isPlacing = true
        let serverPosition = await store.placeContribution(contribution)
        guard let serverPosition else {
            isPlacing = false
            withAnimation { dragOffset = .zero; isMagneticallyAligned = false }
            return
        }
        finalPosition = serverPosition
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            dragOffset = .zero
            isMagneticallyAligned = false
            placed = true
        }
        try? await Task.sleep(for: .milliseconds(550))
        finalPosition = nil
        isPlacing = false
    }
}
