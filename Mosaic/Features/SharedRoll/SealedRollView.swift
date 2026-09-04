import SwiftUI

struct SealedRollView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MosaicScreen {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Your memories")
                            .font(MosaicTheme.display(38, weight: .semibold))
                        Text("Photos, videos, and notes stay private until reveal. You can remove any memory before then.")
                            .font(.subheadline).foregroundStyle(MosaicTheme.muted)
                    }
                    if store.challenge.sharedMoments.isEmpty {
                        ContentUnavailableView("No memories yet", systemImage: "photo.on.rectangle.angled",
                                               description: Text("Add a photo, short video, or note to help tell the story."))
                            .porcelainCard()
                        Button("Add a memory") { dismiss(); store.openSharedCamera() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    ForEach(Array(store.challenge.sharedMoments.sorted { $0.createdAt > $1.createdAt }.enumerated()), id: \.element.id) { index, moment in
                        undevelopedCard(moment, index: index)
                    }
                }
            }
            .navigationTitle("Memories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func undevelopedCard(_ moment: SharedMoment, index: Int) -> some View {
        OrganicPanel(variant: OrganicPanelVariant.allCases[index % OrganicPanelVariant.allCases.count], tint: MosaicTheme.claySurface) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Image(systemName: moment.lifecycle == .rejected ? "eye.slash" : mediaIcon(moment.mediaKind))
                        .font(.title2).foregroundStyle(MosaicTheme.indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stateTitle(moment.lifecycle)).font(.headline)
                        Text(moment.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(MosaicTheme.muted)
                    }
                    Spacer()
                    if moment.exportConsent {
                        Label("In recap", systemImage: "checkmark.circle.fill")
                            .font(MosaicTheme.caption(.bold)).foregroundStyle(MosaicTheme.sage)
                    }
                }
                if let note = moment.note { Text(note).font(.subheadline).lineLimit(2) }
                if moment.lifecycle == .uploadPending {
                    Label("Waiting to upload—safe on this iPhone", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption).foregroundStyle(MosaicTheme.persimmon)
                }
                if moment.lifecycle == .rejected {
                    Text("This moment will stay private and will not appear at reveal.")
                        .font(.footnote).foregroundStyle(MosaicTheme.muted)
                }
                HStack {
                    if moment.lifecycle == .localDraft {
                        Button("Add to Mosaic") { Task { await store.sealPrivateDraft(moment.id) } }
                            .buttonStyle(SecondaryButtonStyle())
                    } else if moment.lifecycle.isSealed {
                        Button("Remove from reveal") { Task { await store.revokeSharedMoment(moment.id) } }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    Button("Delete", role: .destructive) { Task { await store.deleteSharedMoment(moment.id) } }
                        .buttonStyle(.plain).font(.subheadline.weight(.semibold))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(moment.mediaKind.rawValue.capitalized) memory, \(stateTitle(moment.lifecycle))")
    }

    private func stateTitle(_ lifecycle: SharedMomentLifecycle) -> String {
        switch lifecycle {
        case .localDraft: "Private draft"
        case .uploadPending: "Waiting to upload"
        case .sealedPendingReview: "Waiting for approval"
        case .sealed: "Sealed for reveal"
        case .approved: "Ready for reveal"
        case .rejected: "Kept private"
        case .deleted: "Deleted"
        case .reported: "Under review"
        case .consentRevoked: "Removed from reveal"
        }
    }

    private func mediaIcon(_ kind: SharedMomentMediaKind) -> String {
        switch kind {
        case .photo: "photo.fill"
        case .video: "video.fill"
        case .note: "text.quote"
        }
    }
}
