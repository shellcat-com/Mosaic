import SwiftUI

struct KinderBlockCreationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int
    @State private var draft = KinderBlockDraftStore.load()
    @State private var searchText = ""
    @State private var isCreating = false
    @State private var creationFailed = false
    @State private var createdChallenge: KindnessChallenge?

    private let stepTitles = ["Interests", "Artwork", "Preview", "Details", "Timing", "Review"]

    init(initialStep: Int = 0) {
        _step = State(initialValue: min(max(initialStep, 0), 5))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                TabView(selection: $step) {
                    interestsStep.tag(0)
                    galleryStep.tag(1)
                    previewStep.tag(2)
                    detailsStep.tag(3)
                    timingStep.tag(4)
                    reviewStep.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.32), value: step)
                controls
            }
            .porcelainBackground()
            .navigationTitle("Create a Kinder Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if step > 0 && createdChallenge == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Start over", role: .destructive) {
                            draft = ChallengeDraft()
                            searchText = ""
                            step = 0
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }
            .onChange(of: draft) { _, newValue in
                KinderBlockDraftStore.save(newValue)
            }
            .task {
                await store.loadMuseumCatalog()
                if let first = filteredMuseumArtworks.first, draft.artworkID == nil {
                    draft.artworkID = first.id
                } else if store.museumCatalog.isEmpty {
                    // The bundled procedural catalog is the intentional offline fallback.
                    draft.usesMuseumArtwork = false
                    await store.trackMuseumReveal(.legacyFallbackUsed)
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 9) {
            HStack {
                Text(stepTitles[step].uppercased())
                Spacer()
                Text("\(step + 1) / \(stepTitles.count)")
            }
            .font(MosaicTheme.caption(.bold))
            .tracking(0.8)
            .foregroundStyle(MosaicTheme.muted)

            MosaicProgressRail(
                current: step + 1,
                total: stepTitles.count,
                tint: selectedArtwork?.dominantColors.first.map { Color(museumHex: $0) }
                    ?? draft.selection.theme.signatureHex.first.map { Color(hex: $0) }
                    ?? MosaicTheme.indigo
            )
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(MosaicTheme.paper.opacity(0.92))
    }

    private var interestsStep: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 24) {
                wizardHeading(
                    eyebrow: "Begin with what they love",
                    title: "What feels like your community?",
                    copy: "Choose up to three interests. We’ll bring relevant public-domain museum artworks to the front."
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(KinderThemeCollection.allCases) { collection in
                        let selected = draft.interests.contains(collection)
                        Button {
                            if selected {
                                draft.interests.remove(collection)
                            } else if draft.interests.count < 3 {
                                draft.interests.insert(collection)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: collection.symbol)
                                    .font(.system(size: 27, weight: .semibold))
                                    .symbolRenderingMode(.hierarchical)
                                Text(collection.title)
                                    .font(MosaicTheme.display(18, weight: .semibold))
                                    .multilineTextAlignment(.leading)
                                Text("\(store.museumCatalog.filter { $0.collection == collection }.count) artworks")
                                    .font(.caption.weight(.semibold))
                                    .opacity(0.68)
                            }
                            .foregroundStyle(selected ? Color.white : MosaicTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
                            .padding(15)
                            .background(selected ? MosaicTheme.indigo : MosaicTheme.paper, in: OrganicPanelShape(variant: selected ? .leaningRight : .softRectangle))
                            .overlay {
                                OrganicPanelShape(variant: selected ? .leaningRight : .softRectangle)
                                    .stroke(selected ? Color.white.opacity(0.45) : MosaicTheme.border, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }

                Button("Show all museum artworks") {
                    draft.interests = []
                    step = 1
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var galleryStep: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 18) {
                wizardHeading(
                    eyebrow: draft.usesMuseumArtwork
                        ? (store.museumCatalog.isEmpty ? "Reviewed museum works" : "\(store.museumCatalog.count) reviewed museum works")
                        : "Offline collection",
                    title: "Choose the artwork they’ll reveal.",
                    copy: draft.usesMuseumArtwork
                        ? "Public-domain works from the Art Institute of Chicago, with an approved square crop and full attribution."
                        : "The original procedural collection remains available as the offline fallback."
                )

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MosaicTheme.muted)
                    TextField("Search title or artist", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(MosaicTheme.muted)
                        }
                    }
                }
                .padding(14)
                .background(MosaicTheme.paper, in: HandDrawnCapsule(inset: 0))
                .overlay { HandDrawnCapsule(inset: 1).stroke(MosaicTheme.border, lineWidth: 1) }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    if draft.usesMuseumArtwork {
                        ForEach(filteredMuseumArtworks) { artwork in
                            MuseumArtworkGalleryCard(
                                artwork: artwork,
                                selected: draft.artworkID == artwork.id
                            ) { draft.artworkID = artwork.id }
                        }
                    } else {
                        ForEach(filteredThemes) { theme in
                            ThemeGalleryCard(
                                theme: theme,
                                selected: draft.selection.themeID == theme.id
                            ) {
                                draft.selection = ThemeSelection(
                                    themeID: theme.id,
                                    paletteID: .signature,
                                    seed: theme.seed,
                                    revision: KinderThemeCatalog.revision
                                )
                            }
                        }
                    }
                }

                if draft.usesMuseumArtwork && store.isLoadingMuseumCatalog {
                    ProgressView("Loading the reviewed catalog…")
                        .frame(maxWidth: .infinity)
                        .porcelainCard()
                } else if (draft.usesMuseumArtwork ? filteredMuseumArtworks.isEmpty : filteredThemes.isEmpty) {
                    ContentUnavailableView("No artwork found", systemImage: "paintpalette", description: Text("Try another title, artist, or interest."))
                        .porcelainCard()
                }

                if !store.museumCreationEnabled, !store.museumCatalog.isEmpty {
                    Label("Museum-art creation is staged behind the rollout flag. You can review the complete experience now; creation enables after package telemetry is healthy.", systemImage: "clock.badge.checkmark")
                        .font(.footnote)
                        .foregroundStyle(MosaicTheme.muted)
                        .porcelainCard()
                }
            }
        }
    }

    private var previewStep: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                if let artwork = selectedArtwork {
                    wizardHeading(
                        eyebrow: artwork.collection.title,
                        title: artwork.title,
                        copy: "\(artwork.artistDisplay) · \(artwork.dateDisplay)"
                    )

                    MuseumArtworkRemoteImage(artwork: artwork)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 24))
                        .accessibilityLabel(artwork.altText)

                    Link(destination: artwork.sourceURL) {
                        Label("View artwork at the Art Institute of Chicago", systemImage: "arrow.up.right.square")
                    }
                    .font(.footnote.weight(.semibold))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("WHAT PARTICIPANTS SEE")
                            .font(MosaicTheme.caption(.bold))
                            .tracking(0.9)
                            .foregroundStyle(MosaicTheme.muted)
                        MosaicBoardView(challenge: museumPreviewChallenge)
                            .frame(maxWidth: 330)
                        Text("Only the collection and this sealed palette are shared before reveal. No artwork fragment is exposed.")
                            .font(.footnote)
                            .foregroundStyle(MosaicTheme.muted)
                    }
                    .porcelainCard()
                } else {
                    wizardHeading(
                        eyebrow: draft.selection.theme.collection.title,
                        title: draft.selection.theme.name,
                        copy: draft.selection.theme.tagline
                    )
                    KinderArtworkView(selection: draft.selection, phase: .invitation, cornerRadius: 32, showsTitle: true)
                        .frame(height: 390)
                }

                OrganicPanel(variant: .leaningLeft, tint: MosaicTheme.sage.opacity(0.1)) {
                    HStack(spacing: 13) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(MosaicTheme.sage)
                        Text("Guests see a safe sealed state. The artwork and attribution unlock only when the reveal is authorized.")
                            .font(.footnote)
                            .foregroundStyle(MosaicTheme.muted)
                    }
                }
            }
        }
    }

    private var detailsStep: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                wizardHeading(
                    eyebrow: "Give it a heart",
                    title: "Tell everyone what this block is for.",
                    copy: "Short, warm language works best on invitations and the final Impact Receipt."
                )

                field("Block name", placeholder: "A Kinder Block", text: $draft.name)
                field("Community or group", placeholder: "West Ridge Neighbors", text: $draft.groupName)

                VStack(alignment: .leading, spacing: 9) {
                    Text("Welcome message")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: $draft.purpose)
                        .font(MosaicTheme.body())
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 130)
                        .padding(12)
                        .background(MosaicTheme.paper, in: OrganicPanelShape(variant: .leaningLeft))
                        .overlay { OrganicPanelShape(variant: .leaningLeft).stroke(MosaicTheme.border, lineWidth: 1) }
                    Text("\(draft.purpose.count) / 500")
                        .font(.caption)
                        .foregroundStyle(draft.purpose.count > 500 ? Color.red : MosaicTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private var timingStep: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                wizardHeading(
                    eyebrow: "Set the rhythm",
                    title: "How will the block grow?",
                    copy: "Choose a goal and reveal time. Every contribution still receives equal space."
                )

                OrganicPanel(variant: .leaningLeft) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Kindness goal")
                                    .font(.headline)
                                Text("Number of equal tile spaces")
                                    .font(.caption)
                                    .foregroundStyle(MosaicTheme.muted)
                            }
                            Spacer()
                            Text("\(draft.goal)")
                                .font(MosaicTheme.display(34, weight: .semibold))
                        }
                        if draft.usesMuseumArtwork {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58))], spacing: 10) {
                                ForEach(MuseumBoardSize.sides, id: \.self) { side in
                                    let capacity = side * side
                                    Button("\(capacity)") {
                                        draft.boardSide = side
                                        draft.goal = capacity
                                    }
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(draft.boardSide == side ? .white : MosaicTheme.ink)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(
                                        draft.boardSide == side ? MosaicTheme.indigo : MosaicTheme.paper,
                                        in: .rect(cornerRadius: 12)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(draft.boardSide == side ? .clear : MosaicTheme.border)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(side) by \(side) board, \(capacity) tiles")
                                    .accessibilityAddTraits(draft.boardSide == side ? .isSelected : [])
                                }
                            }
                            Text("\(draft.boardSide) × \(draft.boardSide) equal tiles")
                                .font(.caption)
                                .foregroundStyle(MosaicTheme.muted)
                        } else {
                            Stepper("Kindness goal", value: $draft.goal, in: 1...10_000, step: draft.goal < 100 ? 5 : 25)
                                .labelsHidden()
                        }
                    }
                }

                OrganicPanel(variant: .softRectangle) {
                    VStack(spacing: 14) {
                        DatePicker("Starts", selection: $draft.startDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                        Divider().overlay(MosaicTheme.border)
                        DatePicker("Reveal", selection: $draft.revealDate, in: draft.startDate.addingTimeInterval(60)..., displayedComponents: [.date, .hourAndMinute])
                    }
                    .font(MosaicTheme.body(.medium))
                }

                if draft.revealDate <= draft.startDate {
                    Label("Reveal time must be after the start.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(MosaicTheme.persimmon)
                }
            }
        }
    }

    private var reviewStep: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                if let challenge = createdChallenge {
                    createdView(challenge)
                } else {
                    wizardHeading(
                        eyebrow: "One last look",
                        title: "Your Kinder Block is ready.",
                        copy: "The artwork locks when the first tile is placed, so everyone builds toward the same reveal."
                    )

                    if let artwork = selectedArtwork {
                        MuseumArtworkRemoteImage(artwork: artwork)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 24))
                        Text("\(artwork.title) — \(artwork.artistDisplay)")
                            .font(.footnote)
                            .foregroundStyle(MosaicTheme.muted)
                    } else {
                        KinderArtworkView(selection: draft.selection, phase: .invitation, cornerRadius: 30, showsTitle: true)
                            .frame(height: 320)
                    }

                    OrganicPanel(variant: .leaningRight) {
                        VStack(spacing: 0) {
                            reviewRow("Community", draft.groupName)
                            Divider().overlay(MosaicTheme.border)
                            reviewRow("Goal", "\(draft.goal) acts")
                            Divider().overlay(MosaicTheme.border)
                            reviewRow("Starts", draft.startDate.formatted(date: .abbreviated, time: .shortened))
                            Divider().overlay(MosaicTheme.border)
                            reviewRow("Reveal", draft.revealDate.formatted(date: .abbreviated, time: .shortened))
                        }
                    }

                    Text(draft.purpose)
                        .font(MosaicTheme.display(22, weight: .medium))
                        .foregroundStyle(MosaicTheme.ink)
                        .padding(.horizontal, 5)

                    if creationFailed {
                        Label("The draft is safe. Check your connection and try again.", systemImage: "arrow.clockwise.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(MosaicTheme.persimmon)
                    }
                    if draft.usesMuseumArtwork && !store.museumCreationEnabled {
                        Label("Museum-art creation is not enabled for this server rollout yet. This reviewed draft stays saved.", systemImage: "lock.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(MosaicTheme.persimmon)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if createdChallenge == nil {
            HStack(spacing: 12) {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: 118)
                }
                Button(step == 5 ? "Create Kinder Block" : "Continue") {
                    if step == 5 {
                        Task { await create() }
                    } else {
                        step += 1
                    }
                }
                .buttonStyle(PrimaryButtonStyle(color: step == 5 ? MosaicTheme.persimmon : MosaicTheme.indigo))
                .disabled(!canContinue || isCreating)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(MosaicTheme.paper.opacity(0.96))
        }
    }

    private func createdView(_ challenge: KindnessChallenge) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            wizardHeading(
                eyebrow: "Created with care",
                title: challenge.name,
                copy: "Your handmade invitation is ready to share."
            )
            if challenge.artworkMode == .museum {
                MosaicBoardView(challenge: challenge)
                    .frame(maxWidth: 330)
            } else {
                KinderArtworkView(selection: challenge.theme, phase: .invitation, cornerRadius: 30, showsTitle: true)
                    .frame(height: 330)
            }
            ShareLink(item: MosaicBuildConfiguration.invitationShareText(challengeName: challenge.name, code: challenge.invitationCode)) {
                Label("Share invitation", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Open organizer dashboard") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func wizardHeading(eyebrow: String, title: String, copy: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(MosaicTheme.caption(.bold))
                .tracking(0.9)
                .foregroundStyle(MosaicTheme.persimmon)
            Text(title)
                .font(MosaicTheme.display(34, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(copy)
                .font(.subheadline)
                .foregroundStyle(MosaicTheme.muted)
        }
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.words)
                .padding(15)
                .background(MosaicTheme.paper, in: OrganicPanelShape(variant: .softRectangle))
                .overlay { OrganicPanelShape(variant: .softRectangle).stroke(MosaicTheme.border, lineWidth: 1) }
        }
    }

    private func reviewRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(MosaicTheme.muted)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline.weight(.semibold))
        .frame(minHeight: 48)
    }

    private var filteredThemes: [KinderTheme] {
        let recommended = KinderThemeCatalog.recommendations(for: draft.interests)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return recommended }
        return recommended.filter { theme in
            theme.name.lowercased().contains(query)
                || theme.collection.title.lowercased().contains(query)
                || theme.tags.contains(where: { $0.contains(query) })
        }
    }

    private var selectedArtwork: ArtworkCatalogItem? {
        guard draft.usesMuseumArtwork, let artworkID = draft.artworkID else { return nil }
        return store.museumCatalog.first { $0.id == artworkID }
    }

    private var filteredMuseumArtworks: [ArtworkCatalogItem] {
        let interests = draft.interests
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.museumCatalog.filter { artwork in
            (interests.isEmpty || interests.contains(artwork.collection))
                && (query.isEmpty
                    || artwork.title.lowercased().contains(query)
                    || artwork.artistDisplay.lowercased().contains(query)
                    || artwork.collection.title.lowercased().contains(query))
        }
    }

    private var museumPreviewChallenge: KindnessChallenge {
        let artwork = selectedArtwork
        return KindnessChallenge(
            name: draft.name.isEmpty ? "A Kinder Block" : draft.name,
            purpose: draft.purpose,
            goal: draft.boardSide * draft.boardSide,
            revealDate: draft.revealDate,
            invitationCode: "PREVIEW",
            contributions: [],
            artworkMode: .museum,
            sealedArtwork: SealedArtwork(
                collection: artwork?.collection ?? .community,
                palette: artwork?.dominantColors ?? ["#7A74C9", "#D49A68", "#ECE4D6"],
                boardSide: draft.boardSide
            ),
            artworkCatalogRevision: artwork?.catalogRevision
        )
    }

    private var canContinue: Bool {
        switch step {
        case 0: draft.interests.count <= 3
        case 1, 2: !draft.usesMuseumArtwork || draft.artworkID != nil
        case 3:
            !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !draft.groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !draft.purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && draft.name.count <= 100
                && draft.purpose.count <= 500
        case 4:
            draft.goal > 0
                && draft.goal <= 10_000
                && draft.revealDate > draft.startDate
                && (!draft.usesMuseumArtwork
                    || (MuseumBoardSize.isSupported(side: draft.boardSide)
                        && draft.goal == draft.boardSide * draft.boardSide))
        case 5: draft.isReadyToCreate && (!draft.usesMuseumArtwork || store.museumCreationEnabled)
        default: false
        }
    }

    private func create() async {
        isCreating = true
        creationFailed = false
        if let result = await store.configureChallenge(draft) {
            KinderBlockDraftStore.clear()
            createdChallenge = result
        } else {
            creationFailed = true
        }
        isCreating = false
    }
}

private struct ThemeGalleryCard: View {
    let theme: KinderTheme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                KinderArtworkView(
                    selection: ThemeSelection(themeID: theme.id, paletteID: .signature, seed: theme.seed, revision: KinderThemeCatalog.revision),
                    phase: .thumbnail,
                    cornerRadius: 21
                )
                .frame(height: 178)

                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.name)
                        .font(MosaicTheme.display(18, weight: .semibold))
                        .foregroundStyle(MosaicTheme.ink)
                        .lineLimit(2)
                    Text(theme.collection.title.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(MosaicTheme.muted)
                }
                .padding(.horizontal, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(MosaicTheme.paper, in: OrganicPanelShape(variant: selected ? .leaningRight : .softRectangle))
            .overlay {
                OrganicPanelShape(variant: selected ? .leaningRight : .softRectangle)
                    .stroke(selected ? MosaicTheme.indigo : MosaicTheme.border.opacity(0.7), lineWidth: selected ? 2.4 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct MuseumArtworkGalleryCard: View {
    let artwork: ArtworkCatalogItem
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                MuseumArtworkRemoteImage(artwork: artwork)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 16))
                Text(artwork.title)
                    .font(MosaicTheme.display(17, weight: .semibold))
                    .foregroundStyle(MosaicTheme.ink)
                    .lineLimit(2)
                Text(artwork.artistDisplay)
                    .font(.caption)
                    .foregroundStyle(MosaicTheme.muted)
                    .lineLimit(1)
                Text(artwork.collection.title.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(MosaicTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(MosaicTheme.paper, in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selected ? MosaicTheme.indigo : MosaicTheme.border, lineWidth: selected ? 2.4 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(artwork.title), by \(artwork.artistDisplay), \(artwork.dateDisplay)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct MuseumArtworkRemoteImage: View {
    let artwork: ArtworkCatalogItem
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color(.secondarySystemBackground))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .clipped()
        .task(id: artwork.thumbnailURL) {
            guard let url = artwork.thumbnailURL,
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let source = UIImage(data: data),
                  let cropped = MuseumArtworkImage.crop(source, to: artwork.crop) else { return }
            image = cropped
        }
    }
}

private struct ThemePalettePreview: View {
    let theme: KinderTheme
    let paletteID: KinderThemePaletteID

    var body: some View {
        HStack(spacing: -4) {
            ForEach(Array(theme.signatureHex.prefix(3).enumerated()), id: \.offset) { index, hex in
                Circle()
                    .fill(color(hex, index: index))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1))
            }
        }
        .frame(height: 28)
    }

    private func color(_ hex: UInt32, index: Int) -> Color {
        switch paletteID {
        case .signature: Color(hex: hex)
        case .soft: Color(hex: hex).opacity(0.64)
        case .kilnNight: index == 0 ? Color(hex: 0x282128) : Color(hex: hex)
        }
    }
}

private enum KinderBlockDraftStore {
    private static let key = "mosaic.kinder-block-draft.v1"

    static func load() -> ChallengeDraft {
        guard let data = UserDefaults.standard.data(forKey: key),
              let draft = try? JSONDecoder().decode(ChallengeDraft.self, from: data)
        else { return ChallengeDraft() }
        return draft
    }

    static func save(_ draft: ChallengeDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

private extension Color {
    init(museumHex: String) {
        let normalized = museumHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(normalized, radix: 16) ?? 0x7A74C9
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
