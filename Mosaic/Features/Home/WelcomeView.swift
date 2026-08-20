import SwiftUI

struct WelcomeView: View {
    var body: some View {
        OnboardingView()
    }
}

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedPage = 0
    @State private var showJoin = false
    @State private var showCreate = false
    @State private var selectedArtwork: ArtworkAttribution?

    private let scenes = OnboardingScene.all

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $selectedPage) {
                ForEach(scenes) { scene in
                    ArtworkSceneView(
                        scene: scene,
                        challenge: store.challenge,
                        onShowAttribution: { selectedArtwork = scene.artwork }
                    )
                    .tag(scene.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .easeInOut(duration: MosaicTheme.sceneTransitionDuration), value: selectedPage)

            bottomControls
        }
        .porcelainBackground()
        .sheet(isPresented: $showJoin) {
            InvitationJoinSheet()
        }
        .sheet(isPresented: $showCreate) {
            OrganizerEntryView()
        }
        .sheet(item: $selectedArtwork) { artwork in
            ArtworkAttributionSheet(artwork: artwork)
        }
    }

    private var header: some View {
        HStack {
            MosaicWordmark()
            .accessibilityElement(children: .combine)

            Spacer()

            if selectedPage < scenes.count - 1 {
                Button("Skip") {
                    move(to: scenes.count - 1)
                }
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(MosaicTheme.indigo)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(MosaicTheme.paper, in: HandDrawnCapsule(inset: 0))
                .overlay { HandDrawnCapsule(inset: 1).stroke(MosaicTheme.border, lineWidth: 1) }
                .accessibilityHint("Moves to the challenge invitation")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .frame(height: 54)
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            SceneProgressRail(selectedPage: selectedPage, count: scenes.count)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(selectedPage + 1) of \(scenes.count)")

            Button {
                if selectedPage == scenes.count - 1 {
                    showJoin = true
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
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(EditorialButtonStyle())
            .accessibilityHint(selectedPage == scenes.count - 1 ? "Opens the guest join form" : "Moves to the next onboarding page")

            if selectedPage == scenes.count - 1 {
                Button("Create a Mosaic") { showCreate = true }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityHint("Opens Sign in with Apple for organizers")
                Text("Joining stays free and needs no account.")
                    .font(.caption)
                    .foregroundStyle(MosaicTheme.muted)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(MosaicTheme.porcelain.opacity(0.96))
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

            VStack(alignment: .leading, spacing: -3) {
                Text("mosaic")
                    .font(MosaicTheme.display(21, weight: .semibold))
                Text("KINDNESS, TOGETHER")
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .tracking(1.15)
                    .foregroundStyle(MosaicTheme.ink.opacity(0.55))
            }
        }
        .foregroundStyle(MosaicTheme.ink)
        .accessibilityLabel("Mosaic, kindness together")
    }
}

private struct SceneProgressRail: View {
    let selectedPage: Int
    let count: Int

    var body: some View {
        HStack(spacing: 9) {
            Text(String(format: "%02d", selectedPage + 1))
                .foregroundStyle(MosaicTheme.ink)

            MosaicProgressRail(current: selectedPage + 1, total: count, tint: MosaicTheme.persimmon)

            Text(String(format: "%02d", count))
                .foregroundStyle(MosaicTheme.ink.opacity(0.42))
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .tracking(1)
    }
}

struct InvitationJoinSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var privacy = "First name"

    private let privacyChoices = ["First name", "Anonymous", "Quiet participant"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Join \(store.challenge.name)")
                            .font(MosaicTheme.display(34, weight: .semibold))
                            .foregroundStyle(MosaicTheme.ink)
                        Text("Choose how you’ll appear. You can participate without creating an account.")
                            .font(.subheadline)
                            .foregroundStyle(MosaicTheme.muted)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Display name")
                            .font(.subheadline.weight(.semibold))
                        TextField("Optional", text: $name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .padding(15)
                            .background(MosaicTheme.paper, in: OrganicPanelShape(variant: .softRectangle))
                            .overlay {
                                OrganicPanelShape(variant: .softRectangle)
                                    .stroke(MosaicTheme.clay.opacity(0.3), lineWidth: 1)
                            }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Privacy")
                            .font(.subheadline.weight(.semibold))

                        Picker("Privacy", selection: $privacy) {
                            ForEach(privacyChoices, id: \.self) { choice in
                                Text(choice).tag(choice)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Label {
                        Text("Your evidence stays private and is never automatically shared as a story.")
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(MosaicTheme.sage)
                    }
                    .font(.footnote)
                    .foregroundStyle(MosaicTheme.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MosaicTheme.sage.opacity(0.1), in: OrganicPanelShape(variant: .leaningLeft))

                    Button("Continue as guest") {
                        store.join(name: name, privacy: privacy)
                        dismiss()
                    }
                    .buttonStyle(EditorialButtonStyle())
                }
                .padding(22)
            }
            .porcelainBackground()
            .navigationTitle("Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
    }
}
