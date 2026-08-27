import CoreImage.CIFilterBuiltins
import SwiftUI

struct CreateMosaicView: View {
    @Environment(MosaicAppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var path: [MosaicRoute]
    @State private var draft = MosaicDraft()
    @State private var step = 0
    @State private var created: MosaicEvent?
    @State private var isSaving = false
    @State private var message: String?

    private let stepTitles = ["Basics", "Activities", "Artwork", "Camera", "Timing", "Invite"]

    var body: some View {
        MosaicPage {
            VStack(alignment: .leading, spacing: 20) {
                MosaicTitle(stepTitles[step], eyebrow: "Create Mosaic · \(step + 1) of 6", detail: subtitle)
                    .accessibilityIdentifier("wizard.step.\(stepTitles[step].lowercased())")
                WizardProgress(current: step + 1, total: stepTitles.count)
                stepContent
                if let message { Text(message).font(.footnote).foregroundStyle(.red) }
                controls
            }
        }
        .id(step)
        .navigationTitle("Create")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var subtitle: String {
        switch step {
        case 0: "Give this shared act of kindness a clear home."
        case 1: "Offer concrete ways people can take part."
        case 2: "Choose the public-domain artwork everyone will reveal."
        case 3: "Give every member the same disposable roll."
        case 4: "Everything closes at one fixed reveal moment."
        default: "Share one invitation so everyone can join the same Mosaic."
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: basics
        case 1: activities
        case 2: artwork
        case 3: camera
        case 4: timing
        default: review
        }
    }

    private var basics: some View {
        VStack(spacing: 14) {
            TextField("Mosaic name", text: $draft.name).mosaicField()
            TextField("Community or group", text: $draft.communityName).mosaicField()
            TextField("What brings everyone together?", text: $draft.description, axis: .vertical)
                .lineLimit(3...7).mosaicField()
        }
    }

    private var activities: some View {
        VStack(spacing: 16) {
            ForEach(Array(draft.activities.enumerated()), id: \.element.id) { index, activity in
                VStack(alignment: .leading, spacing: 10) {
                    Text("Activity \(index + 1)").font(.headline)
                    TextField("Kindness activity", text: binding(for: activity.id, keyPath: \.title)).mosaicField()
                    TextField("Why it matters (optional)", text: binding(for: activity.id, keyPath: \.purpose), axis: .vertical).mosaicField()
                    HStack {
                        Button("Move up", systemImage: "arrow.up") { moveActivity(index, by: -1) }
                            .frame(minWidth: 44, minHeight: 44)
                            .disabled(index == 0)
                        Button("Move down", systemImage: "arrow.down") { moveActivity(index, by: 1) }
                            .frame(minWidth: 44, minHeight: 44)
                            .disabled(index == draft.activities.count - 1)
                        Spacer()
                        Button("Delete", systemImage: "trash", role: .destructive) { draft.activities.remove(at: index) }
                            .frame(minWidth: 44, minHeight: 44)
                            .disabled(draft.activities.count == 1)
                    }.labelStyle(.iconOnly).frame(minHeight: 44)
                }.porcelainCard()
            }
            Button("Add activity", systemImage: "plus") { draft.activities.append(.init()) }
                .buttonStyle(MosaicSecondaryButtonStyle())
        }
    }

    private var artwork: some View {
        VStack(spacing: 16) {
            ForEach(CuratedArtwork.collection) { item in
                Button { draft.artwork = item } label: {
                    HStack(spacing: 14) {
                        Image(item.assetName).resizable().scaledToFill().frame(width: 96, height: 82).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.headline)
                            Text(item.artist).font(.subheadline).foregroundStyle(MosaicTheme.muted)
                            Text(item.license).font(.caption).foregroundStyle(MosaicTheme.muted)
                        }
                        Spacer()
                        Image(systemName: draft.artwork.id == item.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(MosaicTheme.accentForeground)
                    }.porcelainCard()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.title), \(item.artist)")
                .accessibilityAddTraits(draft.artwork.id == item.id ? .isSelected : [])
            }
        }
    }

    private var camera: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose the roll").font(.headline)
            ForEach(FilmLookID.allCases) { look in
                let locked = look != .sunwashed && !hasPremiumChoiceAccess
                Button { chooseFilmLook(look) } label: {
                    FilmLookCard(look: look, artwork: draft.artwork, selected: draft.filmLookID == look, locked: locked)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("filmLook.\(look.rawValue)")
                .accessibilityAddTraits(draft.filmLookID == look ? .isSelected : [])
            }
            Text("Exposures per person").font(.headline).padding(.top, 2)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) { shotLimitChoices }
            } else {
                HStack(spacing: 10) { shotLimitChoices }
            }
            Text("A kept photo uses one shot. A retake does not. Members can delete an active photo to recover the shot.")
                .font(.footnote).foregroundStyle(MosaicTheme.muted)
        }
    }

    @ViewBuilder private var shotLimitChoices: some View {
        ForEach(MosaicDraft.supportedShotLimits, id: \.self) { limit in
            let locked = limit > 12 && !hasPremiumChoiceAccess
            Button { chooseShotLimit(limit) } label: {
                HStack(spacing: 6) {
                    Text("\(limit)").font(.system(.title3, design: .monospaced, weight: .bold))
                    Text("SHOTS").font(.caption.weight(.bold)).tracking(0.8)
                    if locked { Image(systemName: "lock.fill").font(.caption) }
                }
                .frame(maxWidth: .infinity, minHeight: 58)
                .foregroundStyle(draft.shotLimit == limit ? MosaicTheme.porcelain : MosaicTheme.ink)
                .background(draft.shotLimit == limit ? MosaicTheme.deepGlaze : MosaicTheme.raisedPaper, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(MosaicTheme.border) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(limit) shots")
            .accessibilityAddTraits(draft.shotLimit == limit ? .isSelected : [])
            .accessibilityIdentifier("shotLimit.\(limit)")
        }
    }

    private var timing: some View {
        VStack(alignment: .leading, spacing: 18) {
            DatePicker("Starts", selection: $draft.startAt, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
            DatePicker("Reveals", selection: $draft.revealAt, in: draft.startAt.addingTimeInterval(60)..., displayedComponents: [.date, .hourAndMinute])
            Text("Tile goal").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 10)], spacing: 10) {
                ForEach(MosaicDraft.supportedGoals, id: \.self) { goal in
                    let locked = goal > 25 && !hasPremiumChoiceAccess
                    Button { chooseGoal(goal) } label: {
                        VStack(spacing: 4) {
                            Text("\(goal)").font(.headline.monospacedDigit())
                            Image(systemName: locked ? "lock.fill" : draft.goal == goal ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(draft.goal == goal ? MosaicTheme.sky.opacity(0.18) : MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(draft.goal == goal ? MosaicTheme.deepGlaze : MosaicTheme.border) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(goal) tiles\(locked ? ", Plus or Event Pass required" : "")")
                    .accessibilityAddTraits(draft.goal == goal ? .isSelected : [])
                    .accessibilityIdentifier("tileGoal.\(goal)")
                }
            }
            Text("Activities, artwork, camera, goal, and timing lock when the Mosaic starts. The complete artwork appears at reveal even if some tiles remain unfilled.")
                .font(.footnote).foregroundStyle(MosaicTheme.muted)
        }.porcelainCard()
    }

    @ViewBuilder
    private var review: some View {
        if let created {
            VStack(alignment: .center, spacing: 18) {
                QRCodeView(value: created.invitationURL.absoluteString).frame(width: 210, height: 210)
                Text(created.invitationCode).font(.system(.title, design: .monospaced, weight: .bold)).textSelection(.enabled)
                ShareLink(item: created.invitationURL, subject: Text("Join \(created.name)"), message: Text("Join our Mosaic and help reveal the artwork together.")) {
                    Label("Share invitation", systemImage: "square.and.arrow.up")
                }.buttonStyle(MosaicPrimaryButtonStyle())
                Button("Open Mosaic") { path = [.event(created.id)] }.buttonStyle(MosaicSecondaryButtonStyle())
            }.frame(maxWidth: .infinity).porcelainCard()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(draft.artwork.assetName).resizable().scaledToFill().frame(width: 92, height: 92).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.communityName.uppercased()).font(.caption2.weight(.bold)).tracking(1).foregroundStyle(MosaicTheme.accentForeground)
                        Text(draft.name).font(MosaicTheme.display(24, weight: .semibold))
                        Text("\(draft.goal) ceramic tiles").font(.subheadline).foregroundStyle(MosaicTheme.muted)
                    }
                }
                Divider()
                Label("\(draft.activities.filter { !$0.title.isEmpty }.count) kindness activities", systemImage: "heart.fill")
                Label("\(draft.filmLookID.title) · \(draft.shotLimit) exposures each", systemImage: "camera.fill")
                Label("Reveals \(draft.revealAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "sparkles")
            }.porcelainCard()
        }
    }

    @ViewBuilder
    private var controls: some View {
        if created == nil {
            if dynamicTypeSize.isAccessibilitySize { VStack(spacing: 12) { controlButtons } }
            else { HStack(spacing: 12) { controlButtons } }
        }
    }

    @ViewBuilder private var controlButtons: some View {
        if step > 0 { Button("Back") { step -= 1 }.buttonStyle(MosaicSecondaryButtonStyle()) }
        if step < 5 {
            Button("Continue") { step += 1 }
                .buttonStyle(MosaicPrimaryButtonStyle())
                .disabled(!canContinue)
                .accessibilityIdentifier("wizard.continue.\(step)")
        } else {
            Button(isSaving ? "Creating…" : "Create Mosaic") { Task { await create() } }
                .buttonStyle(MosaicPrimaryButtonStyle()).disabled(isSaving || !draft.isValid)
        }
    }

    private var canContinue: Bool {
        switch step {
        case 0: !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && !draft.communityName.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: draft.activities.contains { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        case 4: draft.revealAt > draft.startAt
        default: true
        }
    }

    private func binding(for id: UUID, keyPath: WritableKeyPath<KindnessActivityDraft, String>) -> Binding<String> {
        Binding {
            draft.activities.first(where: { $0.id == id })?[keyPath: keyPath] ?? ""
        } set: { value in
            guard let index = draft.activities.firstIndex(where: { $0.id == id }) else { return }
            draft.activities[index][keyPath: keyPath] = value
        }
    }

    private func moveActivity(_ index: Int, by offset: Int) {
        let destination = index + offset
        guard draft.activities.indices.contains(destination) else { return }
        draft.activities.swapAt(index, destination)
    }

    private var hasPremiumChoiceAccess: Bool { model.billing.snapshot.canStartPremiumMosaic }

    private func chooseFilmLook(_ look: FilmLookID) {
        guard look == .sunwashed || hasPremiumChoiceAccess else {
            model.billing.present(.creationChoice)
            return
        }
        draft.filmLookID = look
    }

    private func chooseShotLimit(_ limit: Int) {
        guard limit == 12 || hasPremiumChoiceAccess else {
            model.billing.present(.creationChoice)
            return
        }
        draft.shotLimit = limit
    }

    private func chooseGoal(_ goal: Int) {
        guard goal <= 25 || hasPremiumChoiceAccess else {
            model.billing.present(.creationChoice)
            return
        }
        draft.goal = goal
    }

    private func create() async {
        isSaving = true
        defer { isSaving = false }
        do {
            created = try await model.library.create(draft, billingSnapshot: model.billing.snapshot)
            if draft.requiresPremiumAccess && !model.billing.snapshot.plusActive {
                await model.billing.refreshServer()
            }
        } catch {
            message = error.localizedDescription
            if error.localizedDescription.contains("free_creation_limit") || error.localizedDescription.contains("premium_required") {
                model.billing.present(error.localizedDescription.contains("free_creation_limit") ? .freeCreationLimit : .creationChoice)
            }
        }
    }
}

struct WizardProgress: View {
    let current: Int
    let total: Int
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...total, id: \.self) { item in
                RoundedRectangle(cornerRadius: 3)
                    .fill(item <= current ? MosaicTheme.accentForeground : MosaicTheme.claySurface)
                    .frame(height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
        .accessibilityAddTraits(.isStaticText)
    }
}

private struct FilmLookCard: View {
    let look: FilmLookID
    let artwork: CuratedArtwork
    let selected: Bool
    let locked: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(artwork.assetName)
                .resizable().scaledToFill().frame(width: 92, height: 74).clipped()
                .overlay(tint.blendMode(.softLight))
                .saturation(look == .garden ? 0.78 : 0.9)
                .contrast(1.06)
                .clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text(look.title).font(.headline)
                Text(look.detail).font(.caption).foregroundStyle(MosaicTheme.muted).lineLimit(2)
            }
            Spacer(minLength: 2)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3).foregroundStyle(selected ? MosaicTheme.accentForeground : MosaicTheme.muted)
            if locked { Image(systemName: "lock.fill").foregroundStyle(MosaicTheme.muted) }
        }
        .padding(12)
        .background(selected ? MosaicTheme.sky.opacity(0.17) : MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(selected ? MosaicTheme.accentForeground : MosaicTheme.border, lineWidth: selected ? 1.5 : 1) }
    }

    private var tint: Color {
        switch look {
        case .sunwashed: MosaicTheme.gold.opacity(0.26)
        case .garden: MosaicTheme.sage.opacity(0.25)
        case .afterglow: MosaicTheme.rose.opacity(0.24)
        }
    }
}

struct QRCodeView: View {
    let value: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let image = image {
            Image(uiImage: image).interpolation(.none).resizable().scaledToFit().accessibilityLabel("Mosaic invitation QR code")
        }
    }

    private var image: UIImage? {
        filter.message = Data(value.utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
