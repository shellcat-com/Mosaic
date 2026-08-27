import SwiftUI

struct JoinMosaicView: View {
    @Environment(MosaicAppModel.self) private var model
    let prefilledCode: String?
    @Binding var path: [MosaicRoute]
    @State private var code = ""
    @State private var preview: MosaicInvitationPreview?
    @State private var message: String?
    @State private var isWorking = false

    var body: some View {
        MosaicPage {
            VStack(alignment: .leading, spacing: 22) {
                MosaicTitle("Join a Mosaic", eyebrow: "Invitation only", detail: "Enter the code from the organizer's link or QR card.")
                TextField("Invitation code", text: $code)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .font(.system(.title2, design: .monospaced, weight: .semibold)).mosaicField()
                if let preview { InvitationPreviewCard(preview: preview) }
                Button(preview == nil ? "Preview Mosaic" : "Join Mosaic") {
                    Task { preview == nil ? await resolve() : await join() }
                }.buttonStyle(MosaicPrimaryButtonStyle()).disabled(isWorking || normalizedCode.isEmpty)
                if preview != nil {
                    Button("Use a different code") { preview = nil }.buttonStyle(MosaicSecondaryButtonStyle())
                }
                if let message { Text(message).font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Join")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let prefilledCode else { return }
            code = prefilledCode
            await resolve()
        }
    }

    private var normalizedCode: String { code.uppercased().filter { $0.isLetter || $0.isNumber } }

    private func resolve() async {
        isWorking = true; defer { isWorking = false }
        do { preview = try await model.library.resolve(code: normalizedCode); message = nil }
        catch { message = error.localizedDescription }
    }

    private func join() async {
        isWorking = true; defer { isWorking = false }
        do {
            let event = try await model.library.join(code: normalizedCode)
            path = [.event(event.id)]
        } catch { message = error.localizedDescription }
    }
}
