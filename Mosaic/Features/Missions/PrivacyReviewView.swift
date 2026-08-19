import SwiftUI

struct PrivacyReviewView: View {
    let mission: Mission
    let method: EvidenceMethod
    let reflection: String
    let photoData: Data?
    let videoDuration: Double?

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var includeMemory = false
    @State private var showIdentity = false
    @State private var emotion: Emotion = .hopeful
    @State private var fireTile = false
    @State private var exportConsent = false
    @State private var isSubmitting = false
    @State private var pendingReviewSubmitted = false
    @State private var submissionError: String?
    @State private var submittedContribution: TileContribution?

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

                VStack(spacing: 18) {
                    Toggle(isOn: $includeMemory) {
                        Label("Include this memory", systemImage: "heart")
                    }
                    .tint(MosaicTheme.indigo)

                    if includeMemory {
                        Toggle("Show my name with it", isOn: $showIdentity)
                            .tint(MosaicTheme.indigo)
                        Text("Only this approved memory may appear during the reveal or in exports. You can change this before reveal.")
                            .font(.footnote)
                            .foregroundStyle(MosaicTheme.muted)
                        Toggle("Allow this memory in exports", isOn: $exportConsent)
                            .tint(MosaicTheme.indigo)
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
            Button(pendingReviewSubmitted ? "Done" : (method == .reflection ? "Create my tile" : "Submit private evidence")) {
                if pendingReviewSubmitted { dismiss() }
                else { Task { await submit() } }
            }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSubmitting)
                .opacity(isSubmitting ? 0.65 : 1)
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
        if let photoData, let image = UIImage(data: photoData) {
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
        let contribution = TileContribution(
            id: UUID(),
            mission: mission,
            emotion: emotion,
            evidence: method,
            contributor: showIdentity && !store.displayName.isEmpty ? store.displayName : nil,
            sharedMemory: includeMemory,
            isRevived: false,
            status: method == .reflection ? .selfAttested : .pendingReview
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
            showIdentity: showIdentity,
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
