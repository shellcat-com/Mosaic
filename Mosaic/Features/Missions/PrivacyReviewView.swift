import SwiftUI

struct PrivacyReviewView: View {
    let mission: Mission
    let method: EvidenceMethod
    let reflection: String
    let photoData: Data?
    let videoDuration: Double?

    @Environment(AppStore.self) private var store
    @Environment(MosaicRouter.self) private var router
    @State private var sharing: StorySharing = .tileOnly
    @State private var showIdentity = false
    @State private var emotion: Emotion = .hopeful
    @State private var fireTile = false
    @State private var isSubmitting = false
    @State private var pendingReviewSubmitted = false
    @State private var submissionError: String?
    @State private var submittedContribution: TileContribution?

    private enum StorySharing: String, CaseIterable, Identifiable {
        case tileOnly = "Tile only"
        case recap = "Reveal + recap"
        var id: String { rawValue }
    }

    private var includeMemory: Bool { sharing == .recap }
    private var exportConsent: Bool { sharing == .recap }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                MosaicProgressRail(current: 3, total: 5)
                Text("Keep the proof private")
                    .font(MosaicTheme.display(36, weight: .semibold))

                preview

                VStack(spacing: 0) {
                    privacyRow(icon: "lock.fill", title: "Evidence", value: "Organizer only", color: MosaicTheme.indigo)
                    Divider().padding(.leading, 54)
                    privacyRow(icon: "person.2.fill", title: "Community story", value: includeMemory ? "Included" : "Not included", color: MosaicTheme.sage)
                }
                .porcelainCard()

                VStack(alignment: .leading, spacing: 16) {
                    Text("What should the group see?")
                        .font(.headline)
                    Picker("Story sharing", selection: $sharing) {
                        ForEach(StorySharing.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(sharing == .recap
                         ? "After organizer approval, this memory can appear in the reveal and shareable recap."
                         : "Only your ceramic tile joins the artwork. The evidence remains organizer-only.")
                        .font(.footnote)
                        .foregroundStyle(MosaicTheme.muted)

                    if includeMemory {
                        DisclosureGroup("Name and attribution") {
                            Toggle("Show my name with this memory", isOn: $showIdentity)
                                .tint(MosaicTheme.indigo)
                                .padding(.top, 8)
                        }
                    }
                }
                .porcelainCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose the feeling behind your act")
                        .font(.headline)
                    HStack(spacing: 12) {
                        ForEach(Emotion.allCases) { item in
                            Button {
                                emotion = item
                            } label: {
                                VStack(spacing: 7) {
                                    OrganicPanelShape(variant: OrganicPanelVariant.allCases[(Emotion.allCases.firstIndex(of: item) ?? 0) % OrganicPanelVariant.allCases.count])
                                        .fill(item.color)
                                        .frame(width: 38, height: 38)
                                        .overlay { if emotion == item { Circle().stroke(MosaicTheme.ink, lineWidth: 2).padding(-4) } }
                                    Text(item.title).font(.caption2).foregroundStyle(MosaicTheme.ink)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .accessibilityAddTraits(emotion == item ? .isSelected : [])
                        }
                    }
                }
                .porcelainCard()
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Group {
                if pendingReviewSubmitted {
                    VStack(spacing: 12) {
                        Button {
                            router.finishFlow(at: .groups)
                        } label: {
                            Label("Back to home", systemImage: "house.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button {
                            router.finishFlow(at: .groups)
                        } label: {
                            Label("View Mosaic status", systemImage: "square.grid.2x2.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle(color: MosaicTheme.indigo))
                    }
                } else {
                    Button(method == .reflection ? "Create my tile" : "Submit private evidence") {
                        Task { await submit() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSubmitting)
                    .opacity(isSubmitting ? 0.65 : 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .navigationDestination(isPresented: $fireTile) {
            if let submittedContribution {
                TileFiringView(contribution: submittedContribution)
            }
        }
        .alert("Evidence was not submitted", isPresented: Binding(
            get: { submissionError != nil },
            set: { if !$0 { submissionError = nil } }
        )) {
            Button("Try again") { Task { await submit() } }
            Button("Keep draft", role: .cancel) { }
        } message: {
            Text(submissionError ?? "Please try again.")
        }
    }

    @ViewBuilder
    private var preview: some View {
        if pendingReviewSubmitted {
            VStack(spacing: 14) {
                ZStack {
                    OrganicPanelShape(variant: .leaningLeft)
                        .fill(MosaicTheme.claySurface)
                        .frame(height: 160)
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(MosaicTheme.indigo)
                    Circle().fill(MosaicTheme.persimmon).frame(width: 24, height: 24)
                        .overlay(Image(systemName: "sparkles").font(.caption2.bold()).foregroundStyle(.white))
                        .offset(x: 36, y: 25)
                }
                Text("Memory sealed until reveal")
                    .font(MosaicTheme.display(25, weight: .semibold))
                Text("Your private evidence is with the organizer. The community memory stays undeveloped until it is approved and the kiln opens.")
                    .font(.footnote).foregroundStyle(MosaicTheme.muted).multilineTextAlignment(.center)
            }
            .padding(18).porcelainCard()
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        } else if let photoData, let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .clipShape(OrganicPanelShape(variant: .leaningLeft))
                .overlay(alignment: .bottomLeading) {
                    Label("Private evidence", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white)
                        .padding(10).background(.black.opacity(0.55), in: Capsule()).padding(12)
                }
        } else if !reflection.isEmpty {
            Text("“\(reflection)”")
                .font(MosaicTheme.display(24, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
                .porcelainCard()
        } else {
            Label("Awaiting private \(method.title.lowercased()) verification", systemImage: method.symbol)
                .frame(maxWidth: .infinity, minHeight: 120)
                .porcelainCard()
        }
    }

    private func privacyRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(.white).frame(width: 36, height: 36).background(color, in: Circle())
            Text(title).font(.headline)
            Spacer()
            Text(value).foregroundStyle(MosaicTheme.muted)
        }
        .padding(.vertical, 10)
    }

    private func submit() async {
        guard !isSubmitting, !pendingReviewSubmitted else { return }
        isSubmitting = true
        let id = UUID()
        let localAssetName = photoData.flatMap { LocalMemoryStore.storeSanitizedJPEG($0, id: id) }
        let trimmedReflection = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        let memoryKind: ContributionMemory.Kind
        if localAssetName != nil {
            memoryKind = trimmedReflection.isEmpty ? .photo : .photoWithNote
        } else {
            memoryKind = trimmedReflection.isEmpty ? .tileOnly : .reflection
        }
        let contribution = TileContribution(
            id: id,
            mission: mission,
            emotion: emotion,
            evidence: method,
            contributor: includeMemory && showIdentity && !store.displayName.isEmpty ? store.displayName : nil,
            sharedMemory: includeMemory,
            isRevived: false,
            status: method == .reflection ? .selfAttested : .pendingReview,
            memory: ContributionMemory(
                kind: memoryKind,
                note: trimmedReflection,
                localAssetName: localAssetName,
                recapConsent: includeMemory && exportConsent,
                attributionAllowed: includeMemory && showIdentity
            )
        )
        let mimeType: String? = switch method {
        case .photo, .receipt: "image/jpeg"
        case .video: "video/quicktime"
        default: nil
        }
        let succeeded = await store.submitContribution(
            contribution,
            reflection: reflection,
            mediaData: photoData,
            mimeType: mimeType,
            durationSeconds: videoDuration,
            includeMemory: includeMemory,
            showIdentity: includeMemory && showIdentity,
            exportConsent: exportConsent
        )
        isSubmitting = false
        guard succeeded else {
            submissionError = store.backendMessage ?? "Your draft is safe. Check the connection and retry."
            return
        }
        submittedContribution = contribution
        if method == .reflection || !store.backendState.isLive {
            fireTile = true
        } else {
            pendingReviewSubmitted = true
        }
    }
}
