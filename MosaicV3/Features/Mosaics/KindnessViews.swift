import SwiftUI

struct KindnessActivityView: View {
    @Environment(MosaicAppModel.self) private var model
    let activityID: UUID
    @State private var note = ""
    @State private var isWorking = false
    @State private var feedback: MosaicFeedback?

    private var activity: KindnessActivity? { model.detail.event?.activities.first { $0.id == activityID } }
    private var contribution: KindnessContribution? { model.detail.event?.contributions.first { $0.activityID == activityID && $0.isMine } }

    var body: some View {
        MosaicPage {
            if let activity, let event = model.detail.event {
                VStack(alignment: .leading, spacing: 22) {
                    CeramicTileFront(position: activity.sortOrder, isContributed: contribution != nil)
                        .frame(width: 84, height: 84)
                        .accessibilityHidden(true)
                    MosaicTitle(activity.title, eyebrow: "Kindness activity", detail: activity.purpose.isEmpty ? nil : activity.purpose)
                    if event.phase.acceptsContributions {
                        TextField("Leave an optional note", text: $note, axis: .vertical).lineLimit(3...7).mosaicField()
                        if let contribution {
                            Button("Save note") { Task { await update(contribution) } }.buttonStyle(MosaicPrimaryButtonStyle()).disabled(isWorking)
                            Button("Undo my contribution", role: .destructive) { Task { await undo(contribution) } }.buttonStyle(MosaicSecondaryButtonStyle()).disabled(isWorking)
                        } else {
                            Button("I took part") { Task { await complete(activity) } }.buttonStyle(MosaicPrimaryButtonStyle()).disabled(isWorking)
                            Text("This self-attested confirmation adds one equal-size tile. Photos are separate and never serve as proof.")
                                .font(.footnote).foregroundStyle(MosaicTheme.muted)
                        }
                    } else {
                        ContentUnavailableView("Contributions closed", systemImage: "checkmark.seal", description: Text(event.phase == .full ? "The board is full. The camera stays open until reveal." : "This Mosaic is no longer accepting kindness confirmations."))
                    }
                    if let feedback { MosaicFeedbackView(feedback: feedback) }
                }
            }
        }
        .accessibilityHidden(model.detail.placedTilePosition != nil)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { note = contribution?.note ?? "" }
        .mosaicAccessibilityAnnouncement(feedback?.message)
        .overlay {
            if let position = model.detail.placedTilePosition,
               let event = model.detail.event {
                TilePlacementCeremony(
                    position: position,
                    goal: event.goal,
                    occupiedPositions: event.occupiedTilePositions
                ) {
                    model.detail.clearPlacementCeremony()
                }
            }
        }
    }

    private func complete(_ activity: KindnessActivity) async {
        isWorking = true; defer { isWorking = false }
        do { try await model.detail.complete(activity, note: note); feedback = nil }
        catch { feedback = .init(message: error.localizedDescription, kind: .error) }
    }
    private func update(_ contribution: KindnessContribution) async {
        isWorking = true; defer { isWorking = false }
        do { try await model.detail.updateNote(contributionID: contribution.id, note: note); feedback = .init(message: "Note saved.", kind: .success) }
        catch { feedback = .init(message: error.localizedDescription, kind: .error) }
    }
    private func undo(_ contribution: KindnessContribution) async {
        isWorking = true; defer { isWorking = false }
        do { try await model.detail.undo(contributionID: contribution.id); note = ""; feedback = .init(message: "Contribution withdrawn.", kind: .success) }
        catch { feedback = .init(message: error.localizedDescription, kind: .error) }
    }
}

struct ContributionDetailView: View {
    @Environment(MosaicAppModel.self) private var model
    let contributionID: UUID

    var body: some View {
        MosaicPage {
            if let event = model.detail.event,
               let contribution = event.contributions.first(where: { $0.id == contributionID }),
               let activity = event.activities.first(where: { $0.id == contribution.activityID }) {
                VStack(alignment: .leading, spacing: 18) {
                    CeramicTileFront(position: contribution.tilePosition, isContributed: true)
                        .frame(width: 92, height: 92).accessibilityHidden(true)
                    MosaicTitle(activity.title, eyebrow: "Kindness tile \(contribution.tilePosition + 1)", detail: activity.purpose)
                    VStack(alignment: .leading, spacing: 8) {
                        Label(contribution.contributorDisplayName ?? "Mosaic member", systemImage: "person.crop.circle")
                        Text(contribution.note ?? "No note was added.").font(MosaicTheme.display(24))
                        Text(contribution.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.footnote).foregroundStyle(MosaicTheme.muted)
                    }.porcelainCard()
                }
            }
        }.navigationTitle("Kindness")
    }
}
