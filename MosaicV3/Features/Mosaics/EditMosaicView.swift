import SwiftUI

struct EditMosaicView: View {
    @Environment(MosaicAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let eventID: UUID
    @Binding var path: [MosaicRoute]
    @State private var name = ""
    @State private var description = ""
    @State private var isWorking = false
    @State private var message: String?
    @State private var confirmsDeletion = false

    var body: some View {
        MosaicPage {
            VStack(alignment: .leading, spacing: 22) {
                MosaicTitle(
                    "Edit your Mosaic",
                    eyebrow: "Organizer",
                    detail: "The name and description can change until reveal. Activities, artwork, timing, film look, shot limit, and tile goal are locked once the event starts."
                )
                TextField("Mosaic name", text: $name).mosaicField()
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...7)
                    .mosaicField()
                Button(isWorking ? "Saving…" : "Save changes") {
                    Task { await save() }
                }
                .buttonStyle(MosaicPrimaryButtonStyle())
                .disabled(isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Divider().padding(.vertical, 8)
                Button("Delete Mosaic", role: .destructive) { confirmsDeletion = true }
                    .buttonStyle(MosaicSecondaryButtonStyle())
                    .disabled(isWorking)
                Text("Creator deletion permanently removes the event and its shared content.")
                    .font(.footnote)
                    .foregroundStyle(MosaicTheme.muted)
                if let message { Text(message).font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Edit Mosaic")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: eventID) {
            if model.detail.event?.id != eventID { await model.detail.load(id: eventID) }
            guard let event = model.detail.event, event.isCreator else { return }
            name = event.name
            description = event.description
        }
        .confirmationDialog("Delete this Mosaic?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete Mosaic", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await model.detail.updateMetadata(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if let event = model.detail.event { model.library.replace(event.summary) }
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }

    private func delete() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await model.detail.deleteEvent()
            model.library.remove(id: eventID)
            path.removeAll()
        } catch {
            message = error.localizedDescription
        }
    }
}
