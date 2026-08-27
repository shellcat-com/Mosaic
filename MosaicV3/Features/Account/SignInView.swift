import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(MosaicAppModel.self) private var model
    let invitationCode: String?
    @State private var rawNonce = ""
    @State private var preview: MosaicInvitationPreview?

    var body: some View {
        MosaicPage {
            VStack(alignment: .leading, spacing: 24) {
                MosaicTitle("Kindness, made together.", eyebrow: "Mosaic",
                            detail: "A shared way to practice kindness—without points, rankings, or proof.")
                if let preview {
                    InvitationPreviewCard(preview: preview)
                } else {
                    MosaicWelcomeObject()
                }
                SignInWithAppleButton(.continue) { request in
                    let nonce = AppleNonce.make()
                    rawNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleNonce.hashed(nonce)
                } onCompletion: { result in
                    handle(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(Capsule())
                .disabled(model.session.isWorking)
                Text("An Apple account and display name are required to create, join, contribute, or take photos.")
                    .font(.footnote)
                    .foregroundStyle(MosaicTheme.muted)
                if let message = model.session.message {
                    Text(message).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .task { await loadPreview() }
    }

    private func handle(_ result: Result<ASAuthorization, any Error>) {
        let nonce = rawNonce
        rawNonce = ""
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let token = String(data: data, encoding: .utf8), !nonce.isEmpty else {
                model.session.message = "Sign in with Apple did not return a valid credential. Please try again."
                return
            }
            let name = PersonNameComponentsFormatter().string(from: credential.fullName ?? .init())
            Task {
                await model.session.completeAppleAuthorization(.init(
                    identityToken: token,
                    rawNonce: nonce,
                    appleUserID: credential.user,
                    capturedName: name.isEmpty ? nil : name
                ))
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled { model.session.message = error.localizedDescription }
        }
    }

    private func loadPreview() async {
        guard let invitationCode else { return }
        preview = try? await model.library.resolve(code: invitationCode)
    }
}

struct InvitationPreviewCard: View {
    let preview: MosaicInvitationPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                MosaicTheme.claySurface
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(0..<16, id: \.self) { CeramicTileFront(position: $0, isContributed: $0 < 7) }
                }.padding(18)
            }
            .frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityLabel("Sealed ceramic Mosaic preview")
            Text(preview.name).font(MosaicTheme.display(28, weight: .semibold))
            Text(preview.communityName).font(.subheadline.weight(.semibold))
            Text(preview.description).foregroundStyle(MosaicTheme.muted)
            Text("Reveals \(preview.revealAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.footnote).foregroundStyle(MosaicTheme.muted)
        }
        .porcelainCard()
    }
}

private struct MosaicWelcomeObject: View {
    var body: some View {
        ZStack {
            Image(CuratedArtwork.collection[0].assetName).resizable().scaledToFill()
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { position in
                    CeramicTileFront(position: position, isContributed: true)
                }
            }
            .padding(18)
            .background(MosaicTheme.canvas.opacity(0.88), in: RoundedRectangle(cornerRadius: 18))
            .rotationEffect(.degrees(-3))
            .shadow(color: .black.opacity(0.22), radius: 15, y: 8)
        }
        .frame(height: 250).clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text("KINDNESS TURNS INTO ART")
                .font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
                .padding(14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ceramic kindness tiles turning into shared artwork")
    }
}

struct DisplayNameView: View {
    @Environment(MosaicAppModel.self) private var model
    @State private var name = ""

    var body: some View {
        MosaicPage {
            VStack(alignment: .leading, spacing: 22) {
                MosaicTitle("How should people know you?", eyebrow: "One last detail",
                            detail: "Your display name appears with your kindness contributions and photos after reveal.")
                TextField("Display name", text: $name)
                    .textContentType(.name)
                    .submitLabel(.done)
                    .mosaicField()
                Button(model.session.isWorking ? "Saving…" : "Continue") {
                    Task { await model.session.saveDisplayName(name) }
                }
                .buttonStyle(MosaicPrimaryButtonStyle())
                .disabled(model.session.isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                if let message = model.session.message { Text(message).font(.footnote).foregroundStyle(.red) }
            }
        }
        .onAppear { name = model.session.suggestedDisplayName }
    }
}
