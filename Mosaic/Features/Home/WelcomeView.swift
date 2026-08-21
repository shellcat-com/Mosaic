import SwiftUI

struct WelcomeView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        switch store.entryState {
        case .launching:
            ProgressView("Preparing Mosaic…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .porcelainBackground()
        case .intro:
            OnboardingStoryView(
                onFinish: store.completeIntro,
                onSkip: store.completeIntro
            )
        case .entryChoice:
            OnboardingEntryChoiceView()
        case .resolvingInvitation(let code):
            OnboardingLoadingView(
                title: "Opening invitation",
                detail: "Looking for \(code)…"
            )
        case .invitationPreview(let invitation):
            InvitationPreviewView(invitation: invitation)
        case .joining(let invitation):
            InvitationJoinView(invitation: invitation)
        case .main:
            EmptyView()
        }
    }
}

struct OnboardingStoryView: View {
    let onFinish: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPage = 0
    @State private var selectedArtwork: ArtworkAttribution?

    private let scenes = OnboardingScene.all

    var body: some View {
        VStack(spacing: 0) {
            storyHeader

            TabView(selection: $selectedPage) {
                ForEach(scenes) { scene in
                    ArtworkSceneView(
                        scene: scene,
                        onShowAttribution: { selectedArtwork = scene.artwork }
                    )
                    .tag(scene.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: MosaicTheme.sceneTransitionDuration),
                value: selectedPage
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { storyFooter }
        .porcelainBackground()
        .sheet(item: $selectedArtwork) { artwork in
            ArtworkAttributionSheet(artwork: artwork)
        }
    }

    private var storyHeader: some View {
        HStack {
            MosaicWordmark()
            Spacer()
            Button("Skip", action: onSkip)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(MosaicTheme.indigo)
                .frame(minWidth: 58, minHeight: MosaicTheme.minimumHitTarget)
                .background(MosaicTheme.paper, in: HandDrawnCapsule(inset: 0))
                .overlay { HandDrawnCapsule(inset: 1).stroke(MosaicTheme.border, lineWidth: 1) }
                .accessibilityHint("Skips to the ways to begin")
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .frame(minHeight: 54)
    }

    private var storyFooter: some View {
        VStack(spacing: 12) {
            OnboardingProgressRail(selectedPage: selectedPage, count: scenes.count)

            Button {
                if selectedPage == scenes.count - 1 {
                    onFinish()
                } else {
                    move(to: selectedPage + 1)
                }
            } label: {
                ZStack {
                    Text(scenes[selectedPage].buttonTitle)
                    HStack {
                        Spacer()
                        Image(systemName: selectedPage == scenes.count - 1 ? "arrow.right" : "arrow.up.right")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.13), in: Circle())
                    }
                    .padding(.horizontal, 4)
                }
            }
            .buttonStyle(EditorialButtonStyle())
            .accessibilityHint(selectedPage == scenes.count - 1 ? "Shows the ways to begin" : "Moves to the next page")
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(MosaicTheme.porcelain.opacity(0.97))
    }

    private func move(to page: Int) {
        if reduceMotion {
            selectedPage = page
        } else {
            withAnimation(.easeInOut(duration: MosaicTheme.sceneTransitionDuration)) {
                selectedPage = page
            }
        }
    }
}

private struct MosaicWordmark: View {
    var body: some View {
        HStack(spacing: 9) {
            DoodleIcon(icon: .mosaic, color: MosaicTheme.indigo, lineWidth: 2.3)
                .frame(width: 25, height: 25)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: -3) {
                Text("mosaic")
                    .font(MosaicTheme.display(21, weight: .semibold))
                Text("KINDNESS, TOGETHER")
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .tracking(1.15)
                    .foregroundStyle(MosaicTheme.ink.opacity(0.55))
            }
            .accessibilityHidden(true)
        }
        .foregroundStyle(MosaicTheme.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mosaic, kindness together")
    }
}

private struct OnboardingProgressRail: View {
    let selectedPage: Int
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(index <= selectedPage ? MosaicTheme.persimmon : MosaicTheme.clay.opacity(0.28))
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(selectedPage + 1) of \(count)")
    }
}

private struct OnboardingEntryChoiceView: View {
    @Environment(AppStore.self) private var store
    @State private var code = ""
    @State private var showCreate = false

    private var normalizedCode: String { AppStore.normalizedInvitationCode(code) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MosaicWordmark()
                        .padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Make kindness visible—together.")
                            .font(MosaicTheme.display(38, weight: .semibold))
                            .foregroundStyle(MosaicTheme.ink)
                        Text("Open an invitation from your group or enter its short code.")
                            .font(.body)
                            .foregroundStyle(MosaicTheme.muted)
                    }

                    OrganicPanel(variant: .leaningRight, tint: MosaicTheme.indigo.opacity(0.07)) {
                        VStack(alignment: .leading, spacing: 13) {
                            Label("Join a Mosaic", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(MosaicTheme.display(24, weight: .semibold))

                            TextField("Invitation code", text: $code)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .textContentType(.oneTimeCode)
                                .submitLabel(.continue)
                                .onSubmit(openInvitation)
                                .onChange(of: code) { _, value in
                                    let normalized = String(
                                        value.trimmingCharacters(in: .whitespacesAndNewlines)
                                            .uppercased()
                                            .prefix(12)
                                    )
                                    if normalized != value { code = normalized }
                                    store.onboardingMessage = normalized.isEmpty || AppStore.isValidInvitationCode(normalized)
                                        ? nil
                                        : "Use only letters and numbers."
                                }
                                .padding(15)
                                .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(MosaicTheme.border))
                                .accessibilityHint("Paste or type the code from your invitation")

                            if let message = store.onboardingMessage {
                                Label(message, systemImage: "exclamationmark.circle.fill")
                                    .font(.footnote)
                                    .foregroundStyle(MosaicTheme.persimmon)
                                    .accessibilityLabel("Invitation error: \(message)")
                            }

                            Button("Open invitation", action: openInvitation)
                                .buttonStyle(EditorialButtonStyle())
                                .disabled(!AppStore.isValidInvitationCode(normalizedCode))
                        }
                    }

                    Button("Create a Mosaic") { showCreate = true }
                        .buttonStyle(SecondaryButtonStyle())
                    Text("Creating a permanent Mosaic uses Sign in with Apple. Cancelling safely returns here.")
                        .font(.footnote)
                        .foregroundStyle(MosaicTheme.muted)

                    Button {
                        Task { await store.exploreDemo() }
                    } label: {
                        Label("Explore Demo", systemImage: "sparkles")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Text("No credentials required. Opens the shared showcase and a private organizer sandbox; a bundled read-only showcase is available if the network is down.")
                        .font(.footnote)
                        .foregroundStyle(MosaicTheme.muted)

                    Button("How Mosaic works") { store.showIntro() }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: MosaicTheme.minimumHitTarget)
                }
                .padding(22)
            }
            .scrollDismissesKeyboard(.interactively)
            .porcelainBackground()
        }
        .sheet(isPresented: $showCreate) { OrganizerEntryView() }
    }

    private func openInvitation() {
        Task { await store.resolveInvitation(code: normalizedCode) }
    }
}

private struct InvitationPreviewView: View {
    let invitation: InvitationPreview
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    invitationHeader

                    OrganicPanel(variant: .leaningRight, tint: MosaicTheme.paper) {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("A MOSAIC INVITATION")
                                .font(MosaicTheme.caption(.bold))
                                .tracking(1.5)
                                .foregroundStyle(MosaicTheme.persimmon)
                            Text(invitation.name)
                                .font(MosaicTheme.display(38, weight: .semibold))
                            Text(invitation.groupName)
                                .font(.headline)
                                .foregroundStyle(MosaicTheme.indigo)
                            Text(invitation.purpose)
                                .font(.body)
                                .foregroundStyle(MosaicTheme.muted)

                            Divider().overlay(MosaicTheme.border)

                            HStack(spacing: 14) {
                                invitationFact("Goal", "\(invitation.goal) acts", icon: "square.grid.3x3.fill")
                                invitationFact(
                                    "Reveal",
                                    invitation.revealAt.formatted(.dateTime.month(.abbreviated).day()),
                                    icon: "sparkles"
                                )
                            }
                        }
                    }

                    Label("Private circle · Evidence stays organizer-only", systemImage: "lock.shield.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(MosaicTheme.sage)

                    if invitation.status != "active" {
                        Label("This Mosaic is no longer accepting participants.", systemImage: "clock.badge.exclamationmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(MosaicTheme.persimmon)
                    }

                }
                .padding(22)
            }
            .porcelainBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    Button("Join this Mosaic") { store.continueToJoin(invitation) }
                        .buttonStyle(EditorialButtonStyle())
                        .disabled(invitation.status != "active")
                    Button("What is Mosaic?") { store.showIntro(returningTo: invitation) }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(MosaicTheme.porcelain.opacity(0.97))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { store.leaveInvitationFlow() }
                }
            }
        }
    }

    private var invitationHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(MosaicTheme.clay.opacity(0.14))
                .frame(height: 210)
            Image("OnboardingBedroom")
                .resizable()
                .scaledToFill()
                .frame(height: 210)
                .clipped()
                .opacity(0.72)
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(MosaicTheme.indigo)
                .frame(width: 94, height: 94)
                .background(MosaicTheme.paper.opacity(0.94), in: Circle())
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("An invitation to \(invitation.name)")
    }

    private func invitationFact(_ title: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MosaicTheme.muted)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InvitationJoinView: View {
    let invitation: InvitationPreview
    @Environment(AppStore.self) private var store
    @State private var privacy: ParticipantPrivacy = .firstName
    @State private var name = ""

    private var canSubmit: Bool {
        privacy == .anonymous || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Join \(invitation.name)")
                            .font(MosaicTheme.display(34, weight: .semibold))
                        Text("Choose how you’ll appear. Joining stays free and needs no account.")
                            .font(.subheadline)
                            .foregroundStyle(MosaicTheme.muted)
                    }

                    VStack(spacing: 12) {
                        ForEach(ParticipantPrivacy.onboardingChoices, id: \.self) { choice in
                            PrivacyChoiceCard(
                                privacy: choice,
                                selected: privacy == choice,
                                action: { privacy = choice; store.onboardingMessage = nil }
                            )
                        }
                    }

                    if privacy == .firstName {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("First name")
                                .font(.subheadline.weight(.semibold))
                            TextField("Your first name", text: $name)
                                .textContentType(.givenName)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.continue)
                                .onSubmit(join)
                                .padding(15)
                                .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(MosaicTheme.border))
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Label(
                        "Evidence stays private. Sharing a memory or your name is always a separate choice.",
                        systemImage: "lock.shield.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(MosaicTheme.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MosaicTheme.sage.opacity(0.1), in: OrganicPanelShape(variant: .leaningLeft))

                    if let message = store.onboardingMessage {
                        Label(message, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(MosaicTheme.persimmon)
                    }

                }
                .padding(22)
            }
            .scrollDismissesKeyboard(.interactively)
            .porcelainBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(store.isJoiningInvitation ? "Joining…" : "Continue as guest", action: join)
                    .buttonStyle(EditorialButtonStyle())
                    .disabled(!canSubmit || store.isJoiningInvitation)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(MosaicTheme.porcelain.opacity(0.97))
            }
            .navigationTitle("Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        store.onboardingMessage = nil
                        store.entryState = .invitationPreview(invitation)
                    }
                    .disabled(store.isJoiningInvitation)
                }
            }
        }
        .interactiveDismissDisabled(store.isJoiningInvitation)
    }

    private func join() {
        guard canSubmit, !store.isJoiningInvitation else { return }
        Task { await store.joinInvitation(invitation, name: name, privacy: privacy) }
    }
}

private struct PrivacyChoiceCard: View {
    let privacy: ParticipantPrivacy
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: privacy == .firstName ? "person.crop.circle.fill" : "eye.slash.fill")
                    .font(.title2)
                    .foregroundStyle(selected ? MosaicTheme.indigo : MosaicTheme.muted)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 5) {
                    Text(privacy.title)
                        .font(.headline)
                        .foregroundStyle(MosaicTheme.ink)
                    Text(privacy.detail)
                        .font(.footnote)
                        .foregroundStyle(MosaicTheme.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? MosaicTheme.indigo : MosaicTheme.clay)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(selected ? MosaicTheme.indigo.opacity(0.09) : MosaicTheme.paper, in: OrganicPanelShape(variant: .softRectangle))
            .overlay {
                OrganicPanelShape(variant: .softRectangle)
                    .stroke(selected ? MosaicTheme.indigo : MosaicTheme.border, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct OnboardingLoadingView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large).tint(MosaicTheme.indigo)
            Text(title).font(MosaicTheme.display(30, weight: .semibold))
            Text(detail).font(.subheadline).foregroundStyle(MosaicTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .porcelainBackground()
    }
}
