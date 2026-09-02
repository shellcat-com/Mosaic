import Observation
import SwiftUI

struct RecapEditorView: View {
    let challenge: KindnessChallenge
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: RecapEditorModel
    @State private var panel: Panel = .edits
    @State private var showShare = false
    @State private var showError = false
    @State private var resumeAfterMusic = false
    @State private var shareItems: [Any] = []

    enum Panel: String, CaseIterable { case edits = "Style", music = "Music", details = "Details" }

    init(challenge: KindnessChallenge) {
        self.challenge = challenge
        _model = State(initialValue: RecapEditorModel(challenge: challenge))
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        preview
                        if model.sources.isEmpty {
                            Label(
                                "No moments were approved for export, so this recap is an artwork keepsake.",
                                systemImage: "photo.artframe"
                            )
                            .font(MosaicTheme.body(.medium))
                            .foregroundStyle(MosaicTheme.muted)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else if model.sources.count < 3 {
                            Label(
                                "This shorter, artwork-led recap uses each approved moment once.",
                                systemImage: "sparkles"
                            )
                            .font(MosaicTheme.body(.medium))
                            .foregroundStyle(MosaicTheme.muted)
                        }
                        editorPicker
                        panelContent
                        exportControls
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .background(MosaicTheme.canvas)
                .navigationTitle("Recap")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("Close")
                    }
                }
            }

            if model.isExporting {
                Color.black.opacity(0.22).ignoresSafeArea()
                RecapExportProgressView(progress: model.exportProgress, status: model.exportStatus, cancel: model.cancelExport)
            }
        }
        .task { await model.load(reduceMotion: reduceMotion) }
        .onDisappear { model.stop() }
        .sheet(isPresented: $showShare) {
            RecapActivitySheet(items: shareItems)
        }
        .alert("Recap needs attention", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: { Text(model.errorMessage ?? "Please try again.") }
        .onChange(of: model.errorMessage) { _, value in showError = value != nil }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your story, in motion")
                    .font(MosaicTheme.display(36, weight: .semibold))
                    .foregroundStyle(MosaicTheme.ink)
                Text(challenge.name)
                    .font(MosaicTheme.body())
                    .foregroundStyle(MosaicTheme.muted)
            }

            HStack(spacing: 8) {
                MetricPill(icon: "photo.stack", text: "\(model.sources.count) memories")
                MetricPill(icon: "wand.and.stars", text: model.preset.name)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var preview: some View {
        VStack(spacing: 12) {
            RecapPlayerView(
                request: model.renderRequest,
                currentTime: $model.currentTime,
                isPlaying: model.isPlaying,
                onTogglePlayback: model.togglePlayback
            )
            .frame(maxHeight: 500)
            .padding(.horizontal, 32)

            if let timeline = model.timeline {
                VStack(spacing: 4) {
                    Slider(value: $model.currentTime, in: 0...max(timeline.totalDuration, 0.1))
                        .tint(MosaicTheme.indigo)
                        .accessibilityLabel("Recap position")
                    HStack {
                        Text(time(model.currentTime))
                        Spacer()
                        Text(time(timeline.totalDuration))
                    }
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(MosaicTheme.muted)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 20)
        .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MosaicTheme.border, lineWidth: 1)
        }
    }

    private var editorPicker: some View {
        Picker("Editor panel", selection: $panel) {
            ForEach([Panel.edits, Panel.music], id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: panel) { previous, next in
            if next == .music {
                resumeAfterMusic = model.isPlaying
                model.pause()
            } else if previous == .music, resumeAfterMusic {
                resumeAfterMusic = false
                model.play()
            }
        }
    }

    @ViewBuilder private var panelContent: some View {
        switch panel {
        case .edits:
            VStack(alignment: .leading, spacing: 16) {
                sectionHeading("Choose a style", detail: "Each style changes the pacing, layout, and color of your recap.")
                RecapPresetPicker(selected: model.preset) { model.selectPreset($0) }
            }
        case .music:
            VStack(alignment: .leading, spacing: 16) {
                sectionHeading("Choose the soundtrack", detail: "Preview licensed tracks or let the memories play without music.")
                RecapMusicPicker(selection: $model.audio, recapDuration: model.timeline?.totalDuration ?? 20)
                    .onChange(of: model.audio) { _, _ in model.rebuildTimeline() }
            }
        case .details:
            VStack(alignment: .leading, spacing: 16) {
                sectionHeading("Story details", detail: "Choose how much context appears around the memories.")

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reflection cards")
                            .font(MosaicTheme.body(.medium))
                        Picker("Reflection cards", selection: $model.options.reflectionDensity) {
                            ForEach(RecapDetailsOptions.ReflectionDensity.allCases, id: \.self) {
                                Text($0.rawValue.capitalized).tag($0)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    Divider()
                    Toggle("Show allowed names", isOn: $model.options.showAttribution)
                    Divider()
                    Toggle("Show act labels", isOn: $model.options.showMissionLabels)
                    Divider()
                    Toggle("Include impact receipt", isOn: $model.options.showImpactReceipt)
                }
                .font(MosaicTheme.body())
                .padding(16)
                .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(MosaicTheme.border, lineWidth: 1)
                }
            }
            .tint(MosaicTheme.indigo)
            .onChange(of: model.options) { _, _ in model.rebuildTimeline() }
        }
    }

    private var exportControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading("Ready to share?", detail: "Mosaic exports a vertical video made from the choices above.")

            Button {
                if let url = model.exportURL {
                    shareItems = RecapShareService.activityItems(videoURL: url, music: model.selectedMusic)
                    showShare = true
                } else {
                    model.export {
                        guard let url = model.exportURL else { return }
                        shareItems = RecapShareService.activityItems(videoURL: url, music: model.selectedMusic)
                        showShare = true
                    }
                }
            } label: {
                Label(model.exportURL == nil ? "Create & Share Recap" : "Share Recap", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.renderRequest == nil)

            if model.exportURL != nil {
                HStack(spacing: 8) {
                    Button {
                        Task {
                            do { try await model.saveToPhotos() }
                            catch { model.errorMessage = error.localizedDescription }
                        }
                    } label: {
                        Label("Save", systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        Task { await model.publishToGroup() }
                    } label: {
                        if model.isPublishing {
                            ProgressView()
                        } else {
                            Label(model.isPublished ? "Shared" : "Group", systemImage: model.isPublished ? "checkmark" : "person.2")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(model.isPublished || model.isPublishing)
                }
            }

            Menu {
                Button { shareCard(.finalMosaic) } label: {
                    Label("Final mosaic card", systemImage: "square.grid.2x2")
                }
                Button { shareCard(.impactReceipt) } label: {
                    Label("Impact receipt card", systemImage: "heart.text.square")
                }
            } label: {
                Label("Share a still image", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(SecondaryButtonStyle())

            Label("1080 × 1920 video · Music credit included", systemImage: "checkmark.shield.fill")
                .font(MosaicTheme.caption())
                .foregroundStyle(MosaicTheme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(MosaicTheme.display(26, weight: .semibold))
                .foregroundStyle(MosaicTheme.ink)
            Text(detail)
                .font(MosaicTheme.caption())
                .foregroundStyle(MosaicTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func time(_ seconds: TimeInterval) -> String {
        String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }

    private func shareCard(_ kind: RecapShareService.StaticCardKind) {
        do {
            let url = try model.makeStaticCard(kind)
            shareItems = [url, "Created with Mosaic · \(challenge.name)"]
            showShare = true
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

@MainActor
@Observable
final class RecapEditorModel {
    let challenge: KindnessChallenge
    var meta: RecapMeta?
    var sources: [RecapSource] = []
    var preset = RecapPresetCatalog.recommended
    var audio = RecapAudioSelection(trackID: RecapPresetCatalog.recommended.defaultMusicID, trimOffset: 0)
    var options = RecapDetailsOptions()
    var timeline: RecapTimeline?
    var currentTime: TimeInterval = 0
    var isPlaying = false
    var isExporting = false
    var exportProgress = 0.0
    var exportStatus: RecapExportStatus = .queued
    var exportURL: URL?
    var errorMessage: String?
    var isPublishing = false
    var isPublished = false
    private var reduceMotion = false
    private var playbackTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?
    private let composer = RecapComposer()
    private let cloudAdapter: SupabaseRecapAdapter?

    init(challenge: KindnessChallenge) {
        self.challenge = challenge
        if let sharedClient = AppDependencies.live?.client {
            cloudAdapter = SupabaseRecapAdapter(client: sharedClient)
        } else {
            cloudAdapter = SupabaseConfiguration.current.map(SupabaseRecapAdapter.init(configuration:))
        }
    }

    var selectedMusic: RecapMusicTrack? { RecapMusicCatalog.track(id: audio.trackID) }
    var renderRequest: RecapRenderRequest? {
        guard let meta, let timeline else { return nil }
        return RecapRenderRequest(meta: meta, timeline: timeline, options: options, music: selectedMusic)
    }

    func load(reduceMotion: Bool) async {
        self.reduceMotion = reduceMotion
        do {
            let loaded: (RecapMeta, [RecapSource])
            if let cloudAdapter {
                do {
                    loaded = try await cloudAdapter.loadRecap(challengeID: challenge.id)
                } catch {
                    loaded = try await AppStoreRecapAdapter(challenge: challenge).loadRecap(challengeID: challenge.id)
                }
            } else {
                loaded = try await AppStoreRecapAdapter(challenge: challenge).loadRecap(challengeID: challenge.id)
            }
            meta = loaded.0
            sources = RecapCurator.curate(loaded.1)
            rebuildTimeline()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectPreset(_ value: RecapPreset) {
        preset = value
        audio = RecapAudioSelection(trackID: value.defaultMusicID, trimOffset: 0)
        currentTime = 0
        rebuildTimeline()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func rebuildTimeline() {
        let beats = selectedMusic?.beats ?? []
        timeline = RecapTimeline.build(sources: sources, preset: preset, audio: audio, trackBeats: beats, options: options, reduceMotion: reduceMotion)
        if let timeline { currentTime = min(currentTime, timeline.totalDuration) }
    }

    func togglePlayback() { isPlaying ? pause() : play() }

    func play() {
        guard let timeline else { return }
        if currentTime >= timeline.totalDuration { currentTime = 0 }
        isPlaying = true
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            var last = ContinuousClock.now
            while let self, !Task.isCancelled, self.isPlaying {
                try? await Task.sleep(for: .milliseconds(33))
                let now = ContinuousClock.now
                let elapsed = last.duration(to: now)
                last = now
                let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                self.currentTime += seconds
                if self.currentTime >= timeline.totalDuration { self.currentTime = timeline.totalDuration; self.pause() }
            }
        }
    }

    func pause() { isPlaying = false; playbackTask?.cancel(); playbackTask = nil }
    func stop() { pause(); exportTask?.cancel() }

    func export(completion: @escaping @MainActor () -> Void) {
        guard let request = exportRequest else { return }
        pause()
        isExporting = true
        exportProgress = 0
        exportStatus = .queued
        errorMessage = nil
        exportTask = Task {
            do {
                if let cached = await RecapExportCache.shared.cachedURL(for: request) {
                    exportURL = cached
                    isExporting = false
                    try? await cloudAdapter?.record(.completedLocal, request: request, progress: 1,
                                                    outputPath: cached.lastPathComponent, error: nil)
                    completion()
                    return
                }
                for try await event in await composer.export(request) {
                    switch event {
                    case let .progress(value, status):
                        exportProgress = value; exportStatus = status
                        try? await cloudAdapter?.record(status, request: request, progress: value, outputPath: nil, error: nil)
                    case let .completed(url):
                        exportURL = try await RecapExportCache.shared.store(url, for: request)
                        try? await cloudAdapter?.record(.completedLocal, request: request, progress: 1,
                                                        outputPath: exportURL?.lastPathComponent, error: nil)
                    }
                }
                isExporting = false
                if exportURL != nil { UINotificationFeedbackGenerator().notificationOccurred(.success); completion() }
            } catch is CancellationError {
                isExporting = false
                exportStatus = .cancelled
                try? await cloudAdapter?.record(.cancelled, request: request, progress: exportProgress,
                                                outputPath: nil, error: nil)
            } catch {
                isExporting = false
                exportStatus = .failed
                errorMessage = error.localizedDescription
                try? await cloudAdapter?.record(.failed, request: request, progress: exportProgress,
                                                outputPath: nil, error: error.localizedDescription)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    func cancelExport() { exportTask?.cancel(); exportTask = nil; isExporting = false; exportStatus = .cancelled }
    func saveToPhotos() async throws { guard let exportURL else { return }; try await RecapShareService.saveToPhotos(exportURL) }
    func makeStaticCard(_ kind: RecapShareService.StaticCardKind) throws -> URL {
        guard let renderRequest else { throw CocoaError(.fileNoSuchFile) }
        return try RecapShareService.makeStaticCard(request: renderRequest, kind: kind)
    }

    func publishToGroup() async {
        guard let cloudAdapter, let exportURL, let request = exportRequest else {
            errorMessage = "Connect Mosaic to Supabase before sharing this recap with the group."
            return
        }
        isPublishing = true
        defer { isPublishing = false }
        do {
            _ = try await cloudAdapter.publish(file: exportURL, request: request)
            isPublished = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var exportRequest: RecapExportRequest? {
        guard let meta else { return nil }
        return RecapExportRequest(meta: meta, sources: sources, presetID: preset.id, audio: audio, options: options,
                                  reduceMotion: reduceMotion, rendererVersion: RecapFrameRenderer.version)
    }
}
