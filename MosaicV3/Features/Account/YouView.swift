import SwiftUI

struct YouView: View {
    @Environment(MosaicAppModel.self) private var model
    @Binding var path: [MosaicRoute]
    @State private var displayName = ""
    @State private var isDeleting = false
    @State private var message: String?

    var body: some View {
        MosaicPage {
            VStack(alignment: .leading, spacing: 22) {
                MosaicTitle(model.session.profile?.displayName ?? "You", eyebrow: "Mosaic account", detail: "Your name appears with contributions and photos after reveal.")
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Display name", text: $displayName).textContentType(.name).mosaicField()
                    Button("Save display name") { Task { await model.session.saveDisplayName(displayName) } }.buttonStyle(MosaicPrimaryButtonStyle())
                }.porcelainCard()
                MosaicPlusAccountCard()
                accountRow("Joined Mosaics", value: "\(model.library.mosaics.count)", icon: "square.grid.2x2")
                Button { path.append(.blockedUsers) } label: { accountRow("Blocked users", value: nil, icon: "person.crop.circle.badge.xmark") }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Help & safety").font(MosaicTheme.display(24, weight: .semibold))
                    if let supportURL = URL(string: "https://shellcat-com.github.io/Mosaic/support/") {
                        Link("Support", destination: supportURL)
                    }
                    if let guidelinesURL = URL(string: "https://shellcat-com.github.io/Mosaic/community-guidelines/") {
                        Link("Community guidelines", destination: guidelinesURL)
                    }
                    if let privacyURL = URL(string: "https://shellcat-com.github.io/Mosaic/privacy/") {
                        Link("Privacy policy", destination: privacyURL)
                    }
                    Text("Shared photos can be reported, and contributors can be blocked. Reports remove a photo from member galleries while it is reviewed by the developer.")
                        .font(.footnote).foregroundStyle(MosaicTheme.muted)
                }.porcelainCard()
                Button("Sign out") {
                    Task { await model.signOut() }
                }.buttonStyle(MosaicSecondaryButtonStyle())
                Button("Delete account", role: .destructive) { isDeleting = true }.buttonStyle(MosaicSecondaryButtonStyle())
                if let message { Text(message).font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle("You")
        .onAppear { displayName = model.session.profile?.displayName ?? "" }
        .alert("Delete your Mosaic account?", isPresented: $isDeleting) {
            Button("Delete account", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your account, memberships, contributions, and photos. Mosaics you created are also deleted. Deleting your account does not cancel an active Mosaic Plus subscription; manage or cancel it from the Mosaic Plus screen or your App Store subscriptions.")
        }
    }

    private func accountRow(_ title: String, value: String?, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 28).foregroundStyle(MosaicTheme.accentForeground)
            Text(title).foregroundStyle(MosaicTheme.ink)
            Spacer()
            if let value { Text(value).foregroundStyle(MosaicTheme.muted) }
            else { Image(systemName: "chevron.right").foregroundStyle(MosaicTheme.muted) }
        }.frame(minHeight: 44).porcelainCard()
    }

    private func deleteAccount() async {
        do {
            try await model.deleteAccount()
        }
        catch { message = error.localizedDescription }
    }
}

struct BlockedUsersView: View {
    @Environment(MosaicAppModel.self) private var model
    @State private var users: [BlockedUser] = []
    @State private var message: String?

    var body: some View {
        MosaicPage {
            VStack(alignment: .leading, spacing: 18) {
                MosaicTitle("Blocked users", eyebrow: "Your gallery", detail: "Photos from these people stay hidden from your galleries and recap choices.")
                if users.isEmpty {
                    ContentUnavailableView("No blocked users", systemImage: "person.crop.circle.badge.checkmark")
                }
                ForEach(users) { user in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(user.displayName).font(.headline)
                            Text("Blocked \(user.blockedAt.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(MosaicTheme.muted)
                        }
                        Spacer()
                        Button("Unblock") { Task { await unblock(user) } }.frame(minHeight: 44)
                    }.porcelainCard()
                }
                if let message { Text(message).font(.footnote).foregroundStyle(.red) }
            }
        }.navigationTitle("Blocked users").task { await load() }
    }

    private func load() async {
        do { users = try await model.api.blockedUsers() } catch { message = error.localizedDescription }
    }
    private func unblock(_ user: BlockedUser) async {
        do { try await model.api.unblockUser(user.id); users.removeAll { $0.id == user.id } }
        catch { message = error.localizedDescription }
    }
}
