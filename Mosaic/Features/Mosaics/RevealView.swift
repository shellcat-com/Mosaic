import SwiftUI
import UIKit

struct RevealView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if store.challenge.artworkMode == .museum {
            MuseumRevealView()
        } else {
            LegacyRevealView()
        }
    }
}

private struct MuseumRevealView: View {
    enum Phase: Equatable {
        case sealed
        case warming
        case turning
        case complete
    }

    enum CompletedMode: String, CaseIterable, Identifiable {
        case artwork = "Artwork"
        case tiles = "Tiles"
        case stories = "Stories"
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @Environment(MosaicRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .sealed
    @State private var revealProgress = 0.0
    @State private var croppedArtwork: UIImage?
    @State private var completedMode: CompletedMode = .artwork
    @State private var showAttribution = false
    @State private var ceremonyTask: Task<Void, Never>?
    @State private var completionHaptic = 0

    private var verifiedCount: Int {
        store.challenge.contributions.filter { $0.evidence != .reflection }.count
    }

    private var selfAttestedCount: Int {
        store.challenge.contributions.filter { $0.evidence == .reflection }.count
    }

    private var memories: Int {
        store.challenge.contributions.filter(\.sharedMemory).count
            + approvedStories.count
    }

    private var approvedStories: [SharedMoment] {
        store.challenge.sharedMoments.filter {
            $0.lifecycle == .approved && $0.revealConsent
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.08, blue: 0.045), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    toolbar
                    Text(phase == .complete ? "Together, we made this" : "The kiln is opening")
                        .font(MosaicTheme.display(38, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    revealSurface

                    if phase == .complete {
                        impactReceipt
                            .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .bottom)))
                        completedModes
                        completionActions
                    }
                }
                .padding(20)
            }
        }
        .sensoryFeedback(.success, trigger: completionHaptic)
        .task { await prepareReveal() }
        .onDisappear { ceremonyTask?.cancel() }
        .sheet(isPresented: $showAttribution) { attributionSheet }
    }

    private var toolbar: some View {
        HStack {
            if phase == .warming || phase == .turning {
                Button("Skip") { skipCeremony() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
            } else if phase == .complete {
                Button("Replay") { startCeremony() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
            }
            Spacer()
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    private var revealSurface: some View {
        if phase == .complete {
            completedArtworkSurface
        } else {
            VStack(spacing: 16) {
                MosaicBoardView(
                    challenge: store.challenge,
                    mode: phase == .turning ? .revealing : .sealed,
                    revealProgress: revealProgress,
                    croppedArtworkImage: croppedArtwork
                )
                .frame(maxWidth: 350)
                .shadow(color: MosaicTheme.gold.opacity(phase == .warming ? 0.4 : 0.16), radius: 24)

                revealStatus
            }
        }
    }

    private var completedArtworkSurface: some View {
        Group {
            if let croppedArtwork {
                Image(uiImage: croppedArtwork)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 10))
                    .accessibilityLabel(store.revealedArtwork?.altText ?? "Revealed artwork")
            }
        }
        .frame(maxWidth: 360)
    }

    @ViewBuilder
    private var revealStatus: some View {
        switch store.artworkAvailability {
        case .prefetching, .unlocking:
            ProgressView("Opening the secure artwork…")
                .tint(.white)
                .foregroundStyle(.white)
        case .reconnecting(let message):
            VStack(spacing: 12) {
                Label(message, systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Button("Reconnect and reveal") { Task { await prepareReveal(force: true) } }
                    .buttonStyle(SecondaryButtonStyle(color: MosaicTheme.gold))
            }
        default:
            if store.challenge.serverStatus == "awaiting_reveal", Date.now < store.challenge.revealDate {
                VStack(spacing: 4) {
                    Text("Every tile is placed")
                        .font(.headline)
                    Text("Reveals \(store.challenge.revealDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                }
                .foregroundStyle(.white)
            } else if phase == .warming {
                Text("Kiln warming…")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
    }

    private var completedModes: some View {
        VStack(spacing: 16) {
            Picker("Completed Mosaic view", selection: $completedMode) {
                ForEach(CompletedMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }
            .pickerStyle(.segmented)

            switch completedMode {
            case .artwork:
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.revealedArtwork?.title ?? "Museum artwork")
                        .font(MosaicTheme.display(24, weight: .semibold))
                    Text(artworkByline)
                        .font(.subheadline)
                        .foregroundStyle(MosaicTheme.muted)
                    Button("Artwork details and attribution") { showAttribution = true }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .porcelainCard()
            case .tiles:
                MosaicBoardView(challenge: store.challenge, mode: .tiles)
                    .frame(maxWidth: 350)
                    .porcelainCard()
            case .stories:
                storiesView
            }
        }
    }

    @ViewBuilder
    private var storiesView: some View {
        if approvedStories.isEmpty {
            ContentUnavailableView(
                "No approved stories",
                systemImage: "text.bubble",
                description: Text("The artwork and every contribution tile are still here.")
            )
            .porcelainCard()
        } else {
            VStack(spacing: 0) {
                ForEach(approvedStories) { story in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "text.bubble.fill")
                            .foregroundStyle(MosaicTheme.indigo)
                        Text(story.note?.isEmpty == false ? story.note! : "An approved community memory")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    if story.id != approvedStories.last?.id { Divider().padding(.leading, 16) }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 10))
            .foregroundStyle(MosaicTheme.ink)
        }
    }

    private var impactReceipt: some View {
        VStack(spacing: 16) {
            MosaicSticker(kind: .sparkles, size: 56)
            Text("Impact Receipt").font(MosaicTheme.display(30, weight: .semibold))
            Divider()
            receiptRow("Verified or confirmed", "\(verifiedCount)")
            receiptRow("Self-attested reflections", "\(selfAttestedCount)")
            receiptRow("Approved memories", "\(memories)")
            receiptRow("Revived chains", "\(store.challenge.contributions.filter(\.isRevived).count)")
        }
        .foregroundStyle(MosaicTheme.ink)
        .porcelainCard()
    }

    private var completionActions: some View {
        VStack(spacing: 12) {
            Button {
                router.showRecap(for: store.challenge.id)
            } label: {
                Label("Open recap", systemImage: "play.rectangle.on.rectangle.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.indigo))

            ShareLink(item: "Our community completed \(store.challenge.contributions.count) acts of kindness in \(store.challenge.name).") {
                Label("Share the impact", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var attributionSheet: some View {
        NavigationStack {
            List {
                Section("Artwork") {
                    LabeledContent("Title", value: store.revealedArtwork?.title ?? "Unknown")
                    LabeledContent("Artist", value: store.revealedArtwork?.artistDisplay ?? "Unknown")
                    LabeledContent("Date", value: store.revealedArtwork?.dateDisplay ?? "Unknown")
                }
                Section("Source") {
                    Text(store.revealedArtwork?.licenseLabel ?? "CC0 Public Domain Designation")
                    if let url = store.revealedArtwork?.sourceURL {
                        Link("View at the Art Institute of Chicago", destination: url)
                    }
                }
                Section("Image description") {
                    Text(store.revealedArtwork?.altText ?? "No description available.")
                }
            }
            .navigationTitle("Artwork details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { showAttribution = false } }
        }
    }

    private var artworkByline: String {
        guard let artwork = store.revealedArtwork else { return "Art Institute of Chicago" }
        return "\(artwork.artistDisplay) · \(artwork.dateDisplay)"
    }

    private func receiptRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).fontWeight(.semibold) }
            .font(.subheadline)
    }

    private func prepareReveal(force: Bool = false) async {
        if store.challenge.serverStatus == "awaiting_reveal",
           Date.now < store.challenge.revealDate,
           !force {
            await store.prefetchMuseumArtworkIfNeeded()
            return
        }
        guard await store.unlockMuseumArtwork(),
              let url = store.revealedArtworkDisplayURL,
              let image = UIImage(contentsOfFile: url.path),
              let artwork = store.revealedArtwork,
              let cropped = MuseumArtworkImage.crop(image, to: artwork.crop) else { return }
        croppedArtwork = cropped
        startCeremony()
    }

    private func startCeremony() {
        ceremonyTask?.cancel()
        phase = .sealed
        revealProgress = 0
        completedMode = .artwork
        ceremonyTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 700))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.8)) { phase = .warming }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 800))
            guard !Task.isCancelled else { return }
            phase = .turning
            let duration = reduceMotion ? 2.0 : 5.5
            withAnimation(.linear(duration: duration)) { revealProgress = 1 }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            phase = .complete
            completionHaptic += 1
            await store.trackMuseumReveal(.revealComplete)
        }
    }

    private func skipCeremony() {
        ceremonyTask?.cancel()
        revealProgress = 1
        phase = .complete
        completionHaptic += 1
        Task { await store.trackMuseumReveal(.revealSkipped) }
    }
}

private struct LegacyRevealView: View {
    @Environment(AppStore.self) private var store
    @Environment(MosaicRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    private var verifiedCount: Int { store.challenge.contributions.filter { $0.evidence != .reflection }.count }
    private var selfAttestedCount: Int { store.challenge.contributions.filter { $0.evidence == .reflection }.count }
    private var memories: Int {
        store.challenge.contributions.filter(\.sharedMemory).count
            + store.challenge.sharedMoments.filter { $0.lifecycle == .approved && $0.revealConsent }.count
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.13, green: 0.08, blue: 0.045), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        if phase < 2 {
                            Button("Reveal now") { withAnimation(.easeOut(duration: 0.25)) { phase = 2 } }
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.82))
                        }
                        Spacer()
                        Button("Close", systemImage: "xmark") { dismiss() }
                            .labelStyle(.iconOnly).font(.headline).foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(.ultraThinMaterial, in: Circle())
                    }
                    Text(phase >= 1 ? "Together, we made this" : "The kiln is opening")
                        .font(MosaicTheme.display(40, weight: .semibold)).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    ZStack {
                        Circle().fill(MosaicTheme.gold.opacity(phase >= 1 ? 0.24 : 0.04)).blur(radius: 18)
                        KinderArtworkView(selection: store.challenge.theme, phase: .reveal, revealProgress: phase == 0 ? 0.08 : phase == 1 ? 0.72 : 1, cornerRadius: 165)
                            .frame(width: 330, height: 330).clipShape(Circle())
                        MosaicBoard(contributions: Array(store.challenge.contributions.prefix(25)), columns: 5, tileSize: 56)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(MosaicTheme.gold.opacity(phase >= 2 ? 0.9 : 0.2), lineWidth: 3))
                            .shadow(color: MosaicTheme.gold.opacity(phase >= 1 ? 0.55 : 0), radius: 28)
                            .saturation(phase >= 1 ? 0.78 : 0.05).opacity(phase >= 2 ? 0.5 : 0.88)
                            .blur(radius: phase >= 1 ? 0 : 9)
                    }
                    .frame(height: 330)
                    .animation(.easeInOut(duration: reduceMotion ? 0.2 : 1.8), value: phase)
                    if phase >= 2 { impactReceipt }
                    if phase >= 2 {
                        VStack(spacing: 12) {
                            Button { router.showRecap(for: store.challenge.id) } label: {
                                Label("Open recap", systemImage: "play.rectangle.on.rectangle.fill")
                            }.buttonStyle(PrimaryButtonStyle(color: MosaicTheme.indigo))
                            ShareLink(item: "Our community completed \(store.challenge.contributions.count) acts of kindness in \(store.challenge.name).") {
                                Label("Share the impact", systemImage: "square.and.arrow.up")
                            }.buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
                .padding(20)
            }
        }
        .task {
            if reduceMotion { phase = 2; return }
            try? await Task.sleep(for: .seconds(0.7)); guard phase < 2 else { return }; phase = 1
            try? await Task.sleep(for: .seconds(2.2)); guard phase < 2 else { return }
            withAnimation(.easeOut(duration: 0.7)) { phase = 2 }
        }
    }

    private var impactReceipt: some View {
        VStack(spacing: 16) {
            MosaicSticker(kind: .sparkles, size: 56)
            Text("Impact Receipt").font(MosaicTheme.display(30, weight: .semibold))
            Divider()
            receiptRow("Verified or confirmed", "\(verifiedCount)")
            receiptRow("Self-attested reflections", "\(selfAttestedCount)")
            receiptRow("Approved memories", "\(memories)")
            receiptRow("Revived chains", "\(store.challenge.contributions.filter(\.isRevived).count)")
        }
        .foregroundStyle(MosaicTheme.ink)
        .porcelainCard()
    }

    private func receiptRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).fontWeight(.semibold) }.font(.subheadline)
    }
}
