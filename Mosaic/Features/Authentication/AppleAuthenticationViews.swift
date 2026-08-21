import AuthenticationServices
import SwiftUI

struct MosaicAppleSignInButton: View {
    @Environment(AppStore.self) private var store
    let createWorkspace: Bool
    var onCancel: (() -> Void)? = nil
    @State private var rawNonce = ""

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            let nonce = AppleNonce.make()
            rawNonce = nonce
            request.requestedScopes = [.fullName]
            request.nonce = AppleNonce.hashed(nonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let data = credential.identityToken,
                      let token = String(data: data, encoding: .utf8),
                      !rawNonce.isEmpty else {
                    store.accountMessage = "Apple did not return a usable identity token."
                    return
                }
                let value = AppleAuthorization(
                    identityToken: token,
                    rawNonce: rawNonce,
                    givenName: credential.fullName?.givenName,
                    familyName: credential.fullName?.familyName
                )
                Task { await store.completeAppleAuthorization(value, createWorkspace: createWorkspace) }
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code == .canceled {
                    onCancel?()
                } else {
                    store.accountMessage = error.localizedDescription
                }
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHint(createWorkspace ? "Creates or restores your organizer account" : "Saves this guest profile across devices")
    }
}

struct OrganizerEntryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MosaicScreen {
                VStack(alignment: .leading, spacing: 24) {
                    RecoveredTileArtwork()
                    Text("Create a Mosaic")
                        .font(MosaicTheme.display(38, weight: .semibold))
                    Text("Organizing needs a recoverable identity. Apple creates a new Mosaic account or restores the one you already use—there are no separate login and signup forms.")
                        .font(.body)
                        .foregroundStyle(MosaicTheme.muted)
                    if store.sessionState.isAuthenticated {
                        Button("Continue to workspace setup") {
                            store.isShowingOrganizerSetup = true
                            dismiss()
                        }
                        .buttonStyle(EditorialButtonStyle())
                    } else {
                        MosaicAppleSignInButton(createWorkspace: true) {
                            store.accountMessage = "Apple sign-in was cancelled. Explore Demo still includes the complete organizer sandbox."
                            dismiss()
                        }
                    }
                    Label("Your private contributions stay attached when a guest account is upgraded.", systemImage: "checkmark.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(MosaicTheme.muted)
                    if let message = store.accountMessage {
                        Text(message).font(.footnote).foregroundStyle(MosaicTheme.persimmon)
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

struct RecoveredTileArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var marked = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(MosaicTheme.clay.opacity(0.16))
                .frame(height: 230)
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(MosaicTheme.paper)
                .frame(width: 146, height: 146)
                .overlay(RoundedRectangle(cornerRadius: 25).stroke(MosaicTheme.clay, style: StrokeStyle(lineWidth: 2, dash: marked ? [] : [8, 7])))
                .rotationEffect(.degrees(-3))
                .overlay {
                    Image(systemName: marked ? "seal.fill" : "circle.dotted")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(marked ? MosaicTheme.indigo : MosaicTheme.clay)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("An unfinished ceramic tile becoming permanently marked")
        .onAppear {
            if reduceMotion { marked = true }
            else { withAnimation(.easeInOut(duration: 0.8).delay(0.15)) { marked = true } }
        }
    }
}

struct OrganizationSetupView: View {
    @Environment(AppStore.self) private var store
    @State private var organizationName = ""
    @State private var organizerName = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            MosaicScreen {
                VStack(alignment: .leading, spacing: 22) {
                    MosaicSectionHeader(title: "Shape your workspace", eyebrow: "Two small details", icon: .mosaic)
                    TextField("Organization name", text: $organizationName)
                        .textContentType(.organizationName)
                        .mosaicTextField()
                    TextField("Organizer display name", text: $organizerName)
                        .textContentType(.name)
                        .mosaicTextField()
                    Text("You can invite admins and reviewers after setup. Participants join challenges separately and never enter the workspace.")
                        .font(.footnote).foregroundStyle(MosaicTheme.muted)
                    Button(isSaving ? "Creating workspace…" : "Create workspace") {
                        isSaving = true
                        Task {
                            _ = await store.createOrganization(name: organizationName, organizerName: organizerName)
                            isSaving = false
                        }
                    }
                    .buttonStyle(EditorialButtonStyle())
                    .disabled(isSaving || organizationName.trimmingCharacters(in: .whitespaces).isEmpty || organizerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let message = store.accountMessage {
                        Text(message).font(.footnote).foregroundStyle(MosaicTheme.persimmon)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .navigationTitle("Organization")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct WorkspaceInviteAcceptanceView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MosaicScreen {
                VStack(alignment: .leading, spacing: 22) {
                    RecoveredTileArtwork()
                    Text("Join the workspace")
                        .font(MosaicTheme.display(36, weight: .semibold))
                    Text("Collaborator access is tied to a recoverable Apple identity. This single-use link expires seven days after it was created.")
                        .foregroundStyle(MosaicTheme.muted)
                    if store.sessionState.isAuthenticated {
                        Button("Accept invitation") { accept() }
                            .buttonStyle(EditorialButtonStyle())
                    } else {
                        MosaicAppleSignInButton(createWorkspace: false)
                    }
                    if let message = store.accountMessage {
                        Text(message).font(.footnote).foregroundStyle(MosaicTheme.muted)
                    }
                }
            }
            .onChange(of: store.sessionState) { _, state in
                if state.isAuthenticated { accept() }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func accept() {
        guard let token = store.pendingWorkspaceInviteToken else { return }
        Task {
            await store.acceptWorkspaceInvite(token: token)
            store.pendingWorkspaceInviteToken = nil
            store.isShowingInviteAcceptance = false
            dismiss()
        }
    }
}

struct GuestRecoveryPromptView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "seal.fill").font(.title).foregroundStyle(MosaicTheme.indigo)
                Text("Keep this tile")
                    .font(MosaicTheme.display(30, weight: .semibold))
            }
            Text("Save your contribution across devices. Linking Apple keeps the same Mosaic identity and does not change how your name appears in this challenge.")
                .foregroundStyle(MosaicTheme.muted)
            MosaicAppleSignInButton(createWorkspace: false)
            Button("Not now") { store.isShowingRecoveryPrompt = false; dismiss() }
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .porcelainBackground()
        .onChange(of: store.sessionState) { _, state in
            if state.isAuthenticated { store.isShowingRecoveryPrompt = false; dismiss() }
        }
    }
}

private extension View {
    func mosaicTextField() -> some View {
        padding(15)
            .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(MosaicTheme.border))
    }
}
