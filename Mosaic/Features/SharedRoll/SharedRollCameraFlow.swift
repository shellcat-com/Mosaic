import SwiftUI

struct SharedRollCameraFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("mosaic.shared-roll-intro-seen-v1") private var hasSeenIntro = false
    @State private var stage: Stage = .camera
    @State private var photoData: Data?
    @State private var note = ""
    @State private var category: MissionCategory?
    @State private var exportConsent = false
    @State private var attribution: SharedMomentAttribution = .anonymous
    @State private var isSealing = false
    @State private var showReminderChoice = false

    private enum Stage { case intro, camera, review, sealed }

    var body: some View {
        Group {
            switch stage {
            case .intro: privacyIntroduction
            case .camera:
                EvidenceCameraView(challenge: store.challenge) { data in
                    photoData = data
                    stage = .review
                }
            case .review: review
            case .sealed: sealed
            }
        }
        .onAppear {
            if !hasSeenIntro { stage = .intro }
        }
        .confirmationDialog("A gentle reminder?", isPresented: $showReminderChoice, titleVisibility: .visible) {
            Button("Remind me") {
                Task {
                    _ = await LocalMomentReminderService.shared.requestAndSchedule(
                        for: store.challenge.summary, lastActivity: store.lastSealedMomentAt
                    )
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Mosaic can send one last-moment reminder and one reveal reminder for this challenge.")
        }
    }

    private var privacyIntroduction: some View {
        ZStack {
            MosaicTheme.canvas.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    OrganicPanelShape(variant: .softRectangle)
                        .fill(MosaicTheme.paper)
                        .frame(width: 168, height: 132)
                        .rotationEffect(.degrees(-3))
                        .shadow(color: .black.opacity(0.13), radius: 16, y: 9)
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(MosaicTheme.indigo)
                }
                Text("A private roll,\nshared at reveal")
                    .font(MosaicTheme.display(42, weight: .semibold))
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 16) {
                    disclosure("Captures stay on this iPhone until you tap Add to group reveal.", icon: "iphone.gen3")
                    disclosure("Approved moments remain hidden from other members until reveal.", icon: "envelope.badge.shield.half.filled")
                    disclosure("Downloadable recaps need separate permission, which starts off.", icon: "square.and.arrow.up")
                }
                .padding(22)
                .background(MosaicTheme.paper, in: OrganicPanelShape(variant: .leaningLeft))
                Spacer()
                Button("Open camera") {
                    hasSeenIntro = true
                    stage = .camera
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Not now") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(24)
        }
    }

    private var review: some View {
        NavigationStack {
            MosaicScreen {
                VStack(alignment: .leading, spacing: 20) {
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity).aspectRatio(4 / 3, contentMode: .fit)
                            .clipShape(OrganicPanelShape(variant: .leaningRight))
                            .overlay { OrganicPanelShape(variant: .leaningRight).stroke(.white.opacity(0.65), lineWidth: 2) }
                            .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Text("What should this moment remember?")
                            .font(MosaicTheme.display(28, weight: .semibold))
                        TextField("A short note (optional)", text: $note, axis: .vertical)
                            .lineLimit(3)
                            .padding(15)
                            .background(MosaicTheme.canvas, in: RoundedRectangle(cornerRadius: 18))
                        Picker("Editorial label", selection: $category) {
                            Text("No label").tag(MissionCategory?.none)
                            ForEach(MissionCategory.allCases) { item in Text(item.title).tag(Optional(item)) }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(20)
                    .background(MosaicTheme.paper, in: OrganicPanelShape(variant: .softRectangle))

                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Allow in downloadable recaps", isOn: $exportConsent)
                            .tint(MosaicTheme.indigo)
                        Text("Off by default. Your moment can still appear privately at the group reveal.")
                            .font(.caption).foregroundStyle(MosaicTheme.muted)
                        Picker("Attribution", selection: $attribution) {
                            Text("Anonymous").tag(SharedMomentAttribution.anonymous)
                            Text("Show my permitted name").tag(SharedMomentAttribution.permitted)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(20)
                    .background(MosaicTheme.claySurface, in: OrganicPanelShape(variant: .leaningLeft))

                    Button(isSealing ? "Sealing…" : "Add to group reveal") { seal() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isSealing || photoData == nil)
                    Button("Retake") { photoData = nil; stage = .camera }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Keep private draft") {
                        guard let photoData else { dismiss(); return }
                        Task { await store.keepPrivateSharedMoment(jpegData: photoData, note: note); dismiss() }
                    }
                        .buttonStyle(.plain).frame(maxWidth: .infinity)
                    Button("Delete capture", role: .destructive) { photoData = nil; dismiss() }
                        .buttonStyle(.plain).frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Your moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
        }
    }

    private var sealed: some View {
        ZStack {
            MosaicTheme.canvas.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    OrganicPanelShape(variant: .leaningLeft)
                        .fill(MosaicTheme.claySurface)
                        .frame(width: 270, height: 205)
                        .shadow(color: .black.opacity(0.14), radius: 18, y: 10)
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 82, weight: .light))
                        .foregroundStyle(MosaicTheme.indigo)
                    Image(systemName: "sparkles")
                        .foregroundStyle(MosaicTheme.persimmon)
                        .offset(x: 90, y: -72)
                }
                Text("Sealed for the reveal")
                    .font(MosaicTheme.display(38, weight: .semibold))
                Text("No one else can see this moment yet. It will stay undeveloped until the group reveal.")
                    .font(.body).foregroundStyle(MosaicTheme.muted)
                    .multilineTextAlignment(.center).padding(.horizontal, 34)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
        }
    }

    private func disclosure(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(MosaicTheme.indigo).frame(width: 24)
            Text(text).font(.subheadline).foregroundStyle(MosaicTheme.ink)
        }
    }

    private func seal() {
        guard let photoData else { return }
        isSealing = true
        Task {
            let firstMoment = store.challenge.sharedMoments.isEmpty
            if await store.sealSharedMoment(jpegData: photoData, note: note, category: category,
                                            exportConsent: exportConsent, attribution: attribution) != nil {
                withAnimation(.easeInOut(duration: 0.35)) { stage = .sealed }
                if firstMoment { showReminderChoice = true }
            }
            isSealing = false
        }
    }
}
