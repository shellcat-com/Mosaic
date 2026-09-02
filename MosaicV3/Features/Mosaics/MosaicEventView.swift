import SwiftUI
import UIKit

struct MosaicEventView: View {
    @Environment(MosaicAppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let eventID: UUID
    @Binding var path: [MosaicRoute]
    @State private var revealPlayback = RevealPlaybackStore()

    var body: some View {
        MosaicPage {
            if let event = model.detail.event, event.id == eventID {
                VStack(alignment: .leading, spacing: 20) {
                    header(event)
                    if event.phase == .revealed { completed(event) }
                    else { active(event) }
                }
            } else if model.detail.isLoading {
                ProgressView("Loading Mosaic…").frame(maxWidth: .infinity, minHeight: 320)
            } else if let message = model.detail.message {
                ContentUnavailableView("Mosaic unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
            }
        }
        .accessibilityHidden(model.detail.placedTilePosition != nil)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: eventID) {
            await model.detail.load(id: eventID)
            if let event = model.detail.event {
                model.library.replace(event.summary)
                model.camera.synchronize(with: event)
            }
        }
        .overlay {
            if let position = model.detail.placedTilePosition {
                TilePlacementCeremony(
                    position: position,
                    goal: model.detail.event?.goal ?? 9,
                    occupiedPositions: model.detail.event?.occupiedTilePositions ?? [position]
                ) { model.detail.clearPlacementCeremony() }
            }
        }
    }

    private func header(_ event: MosaicEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.communityName.uppercased())
                .font(.caption.weight(.semibold)).foregroundStyle(MosaicTheme.accentForeground)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 1)
            Text(event.name)
                .font(MosaicTheme.display(28, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !event.description.isEmpty {
                Text(event.description).font(.subheadline).foregroundStyle(MosaicTheme.muted)
            }
            if dynamicTypeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 8) { eventFacts(event) } }
            else { HStack(spacing: 8) { eventFacts(event) } }
        }
    }

    @ViewBuilder private func eventFacts(_ event: MosaicEvent) -> some View {
        StatusPill(text: "\(event.contributionCount)/\(event.goal) tiles", systemImage: "square.grid.3x3.fill")
        StatusPill(text: "\(event.memberCount) members", systemImage: "person.2.fill")
    }

    private func active(_ event: MosaicEvent) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            phaseAction(event)
            Text("Kindness side").font(MosaicTheme.display(24, weight: .semibold)).accessibilityAddTraits(.isHeader)
            TileSideStory()
            TileFrontBoard(goal: event.goal, occupiedPositions: event.occupiedTilePositions)
            revealCountdown(event)
            Text("All activities").font(MosaicTheme.display(24, weight: .semibold)).accessibilityAddTraits(.isHeader)
            ForEach(sortedActivities(event)) { activity in
                NavigationLink(value: MosaicRoute.activity(activity.id)) {
                    HStack(spacing: 14) {
                        Image(systemName: activity.participantCompleted ? "checkmark.seal.fill" : "heart.circle")
                            .font(.title2).foregroundStyle(activity.participantCompleted ? MosaicTheme.sage : MosaicTheme.accentForeground)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.title).font(.headline).foregroundStyle(MosaicTheme.ink)
                            if !activity.purpose.isEmpty {
                                Text(activity.purpose)
                                    .font(.subheadline)
                                    .foregroundStyle(MosaicTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(MosaicTheme.muted)
                    }.porcelainCard()
                }.buttonStyle(.plain)
            }
            if event.phase.acceptsPhotos {
                Button {
                    model.router.openCamera(for: event.id)
                } label: {
                    Label("Open disposable camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MosaicSecondaryButtonStyle())
            }
            if event.isCreator {
                InviteCard(event: event)
                NavigationLink(value: MosaicRoute.editEvent(event.id)) {
                    Label("Edit Mosaic", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MosaicSecondaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func phaseAction(_ event: MosaicEvent) -> some View {
        switch event.phase {
        case .scheduled:
            VStack(alignment: .leading, spacing: 8) {
                Text("Kindness begins soon").font(MosaicTheme.display(25, weight: .semibold))
                Text("Starts \(event.startAt.formatted(date: .abbreviated, time: .shortened)). Activities unlock when the Mosaic begins.")
                    .foregroundStyle(MosaicTheme.muted)
            }.porcelainCard()
        case .active:
            if let next = sortedActivities(event).first(where: { !$0.participantCompleted }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR NEXT SMALL ACT").font(MosaicTheme.caption(.semibold)).tracking(1.1).foregroundStyle(MosaicTheme.accentForeground)
                    Text(next.title).font(MosaicTheme.display(27, weight: .semibold))
                    if !next.purpose.isEmpty { Text(next.purpose).foregroundStyle(MosaicTheme.muted) }
                    NavigationLink(value: MosaicRoute.activity(next.id)) {
                        Text("Choose this activity").frame(maxWidth: .infinity)
                    }.buttonStyle(MosaicPrimaryButtonStyle())
                }.porcelainCard()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your kindness is part of this Mosaic").font(MosaicTheme.display(25, weight: .semibold))
                    Text("You have taken part in every available activity. Your notes remain editable until reveal.")
                        .foregroundStyle(MosaicTheme.muted)
                }.porcelainCard()
            }
        case .full:
            VStack(alignment: .leading, spacing: 8) {
                Text("Kindness board complete").font(MosaicTheme.display(25, weight: .semibold))
                Text("Every tile has found a place. The disposable camera stays open until reveal.")
                    .foregroundStyle(MosaicTheme.muted)
            }.porcelainCard()
        case .revealed, .deleted:
            EmptyView()
        }
    }

    private func revealCountdown(_ event: MosaicEvent) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Reveal countdown").font(.headline)
            Text(event.revealAt, style: .relative).font(MosaicTheme.display(28, weight: .semibold))
            Text("Other members' notes and photos stay sealed until then.")
                .font(.footnote).foregroundStyle(MosaicTheme.muted)
        }.porcelainCard()
    }

    private func sortedActivities(_ event: MosaicEvent) -> [KindnessActivity] {
        event.activities.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    private func completed(_ event: MosaicEvent) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("One Mosaic, three ways to remember it")
                .font(MosaicTheme.display(24, weight: .semibold))
            Picker("Completed Mosaic view", selection: Bindable(model.detail).selectedOutcome) {
                ForEach(MosaicDetailStore.CompletedOutcome.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .animation(.easeInOut(duration: 0.22), value: model.detail.selectedOutcome)
            switch model.detail.selectedOutcome {
            case .artwork:
                ArtworkRevealBoard(event: event, decryptedArtworkURL: model.detail.revealedArtworkURL, playback: revealPlayback)
                    .overlay {
                        if revealPlayback.phase == .kilnNight {
                            RoundedRectangle(cornerRadius: 26).fill(MosaicTheme.ink.opacity(0.72))
                                .overlay { ProgressView().tint(MosaicTheme.porcelain).accessibilityLabel("The kiln is opening") }
                        }
                    }
                    .animation(.easeInOut(duration: 0.28), value: revealPlayback.uncoveredPositions.count)
                Text(revealPlayback.isComplete ? "Together, we made this." : "The artwork is opening…")
                    .font(MosaicTheme.display(25, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("\(event.artwork.title) · \(event.artwork.artist)").font(.headline)
                Link("Artwork source and license", destination: event.artwork.sourceURL).font(.footnote)
                if revealPlayback.isComplete {
                    Button("Replay Reveal", systemImage: "arrow.counterclockwise") {
                        revealPlayback.replay(event: event, reduceMotion: UIAccessibility.isReduceMotionEnabled)
                    }
                    .buttonStyle(MosaicSecondaryButtonStyle())
                } else {
                    Button("Skip Reveal") { revealPlayback.skip(event: event) }
                        .buttonStyle(MosaicSecondaryButtonStyle())
                }
                Color.clear.frame(height: 0)
                    .task(id: event.id) {
                        revealPlayback.prepare(
                            event: event,
                            accountID: model.session.userID,
                            reduceMotion: UIAccessibility.isReduceMotionEnabled
                        )
                    }
            case .kindness:
                KindnessTileBoard(event: event) { path.append(.contribution($0)) }
                Text("Tap a contributed tile to read its activity, note, and contributor. Unfilled positions remain porcelain.")
                    .font(.footnote).foregroundStyle(MosaicTheme.muted)
            case .photos:
                PhotoGalleryView(event: event, path: $path)
            }
        }
    }
}

private struct InviteCard: View {
    let event: MosaicEvent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite people").font(.headline)
            if dynamicTypeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 10) { inviteContents } }
            else { HStack { inviteContents } }
        }.porcelainCard()
    }

    @ViewBuilder private var inviteContents: some View {
        QRCodeView(value: event.invitationURL.absoluteString).frame(width: 88, height: 88)
        VStack(alignment: .leading, spacing: 6) {
            Text(event.invitationCode).font(.system(.title3, design: .monospaced, weight: .bold)).textSelection(.enabled)
            ShareLink(item: event.invitationURL) { Label("Share link", systemImage: "square.and.arrow.up") }
        }
    }
}

struct TilePlacementCeremony: View {
    let position: Int
    let goal: Int
    let occupiedPositions: [Int]
    let completion: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playback = PlacementCeremonyModel()
    @AccessibilityFocusState private var continueFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            VStack(spacing: 18) {
                CeramicTileFront(position: position, isContributed: true)
                    .frame(width: playback.phase >= .travel ? 58 : 132, height: playback.phase >= .travel ? 58 : 132)
                    .rotation3DEffect(.degrees(playback.phase == .glaze ? 78 : 0), axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(playback.phase == .lift ? 1.08 : 1)
                    .shadow(color: MosaicTheme.warmShadow, radius: playback.phase == .lift ? 18 : 5, y: playback.phase == .lift ? 12 : 3)
                if playback.phase >= .travel {
                    TileFrontBoard(goal: goal, occupiedPositions: occupiedPositions)
                        .frame(maxWidth: 250)
                        .transition(.scale.combined(with: .opacity))
                }
                VStack(spacing: 5) {
                    Text(playback.phase == .completed ? "Your act is now part of the Mosaic" : "Your tile is finding its place")
                        .font(MosaicTheme.display(25, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text("The assigned position is equal, automatic, and permanent.")
                        .font(.subheadline).foregroundStyle(MosaicTheme.muted)
                }
                if playback.phase == .completed {
                    Button("Continue", action: completion)
                        .buttonStyle(MosaicPrimaryButtonStyle())
                        .accessibilityFocused($continueFocused)
                        .accessibilityIdentifier("placement.continue")
                } else {
                    Button("Skip animation") { playback.skip() }
                        .buttonStyle(MosaicSecondaryButtonStyle())
                        .accessibilityIdentifier("placement.skip")
                }
            }.padding(28).background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 24))
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("placement.ceremony")
        .animation(reduceMotion ? nil : .spring(duration: 0.48), value: playback.phase)
        .onChange(of: playback.phase) { _, phase in
            if phase == .completed { continueFocused = true }
        }
        .task {
            playback.play(reduceMotion: reduceMotion)
        }
    }
}
