import AVFoundation
import AVKit
import Photos
import SwiftUI

struct PhotoRecapBuilderView: View {
    @Environment(MosaicAppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let eventID: UUID
    @State private var project: PhotoRecapProject
    @State private var stage = Stage.select
    @State private var exportURL: URL?
    @State private var exportProgress = 0.0
    @State private var isExporting = false
    @State private var feedback: MosaicFeedback?
    @State private var renderTask: Task<Void, Never>?
    @State private var musicPreviewTask: Task<Void, Never>?
    @State private var musicPlayer: AVAudioPlayer?
    @State private var loadedDraft = false
    @State private var showResetConfirmation = false
    private let renderer = PhotoRecapRenderer()
    private let shouldRestoreDraft: Bool

    enum Stage: String, CaseIterable, Identifiable {
        case select = "Photos"
        case order = "Order"
        case style = "Style"
        case preview = "Preview"
        var id: String { rawValue }
    }

    init(eventID: UUID, initialProject: PhotoRecapProject? = nil, initialStage: Stage = .select) {
        self.eventID = eventID
        shouldRestoreDraft = initialProject == nil
        _project = State(initialValue: initialProject ?? PhotoRecapProject(mosaicID: eventID))
        _stage = State(initialValue: initialStage)
    }

    private var event: MosaicEvent? { model.detail.event?.id == eventID ? model.detail.event : nil }
    private var photos: [EventPhoto] { event?.photos.filter { $0.state == .eligible || $0.state == .sealed } ?? [] }

    var body: some View {
        MosaicPage {
            VStack(alignment: .leading, spacing: 20) {
                MosaicTitle("Your photo recap", eyebrow: "Photos only", detail: "Choose 1–24 developed gallery photos. Each chosen photo appears exactly once.")
                if dynamicTypeSize.isAccessibilitySize {
                    Picker("Recap step", selection: $stage) {
                        ForEach(Stage.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(MosaicTheme.raisedPaper, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(MosaicTheme.border) }
                    .accessibilityIdentifier("recap.stage.menu")
                } else {
                    Picker("Recap step", selection: $stage) {
                        ForEach(Stage.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("recap.stage.segmented")
                }
                switch stage {
                case .select: selectionView
                case .order: orderView
                case .style: styleView
                case .preview: previewView
                }
                if project.hasEdits {
                    Label("Draft saved while you browse this signed-in session.", systemImage: "checkmark.circle")
                        .font(.footnote).foregroundStyle(MosaicTheme.muted)
                }
                if let feedback { MosaicFeedbackView(feedback: feedback) }
            }
        }
        .navigationTitle("Recap")
        .navigationBarTitleDisplayMode(.inline)
        .mosaicAccessibilityAnnouncement(feedback?.message)
        .task { restoreDraftIfNeeded() }
        .onChange(of: project) { _, _ in saveDraft() }
        .onChange(of: stage) { _, _ in saveDraft() }
        .onChange(of: project.music) { _, _ in stopMusicPreview() }
        .onChange(of: project.musicTrimOffset) { _, _ in stopMusicPreview() }
        .onDisappear {
            renderTask?.cancel()
            stopMusicPreview()
        }
        .alert("Start this recap over?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Start over", role: .destructive) { resetProject() }
        } message: {
            Text("Your selected photos, order, template, and music choices will be cleared.")
        }
    }

    private var selectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(project.selection.orderedPhotoIDs.count) of 24 selected").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(photos) { photo in
                    Button { project.selection.toggle(photo.id) } label: {
                        ZStack(alignment: .topTrailing) {
                            PhotoThumbnail(photo: photo).aspectRatio(0.78, contentMode: .fit)
                            if let index = project.selection.orderedPhotoIDs.firstIndex(of: photo.id) {
                                Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.white)
                                    .frame(width: 28, height: 28).background(MosaicTheme.indigo, in: Circle()).padding(6)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recap.photo.\(photo.id.uuidString.lowercased())")
                    .accessibilityLabel(selectionLabel(photo))
                    .accessibilityAddTraits(project.selection.orderedPhotoIDs.contains(photo.id) ? .isSelected : [])
                }
            }
            Button("Order photos") { stage = .order }.buttonStyle(MosaicPrimaryButtonStyle()).disabled(project.selection.orderedPhotoIDs.isEmpty)
            if project.hasEdits {
                Button("Start over", systemImage: "arrow.counterclockwise", role: .destructive) {
                    showResetConfirmation = true
                }
                .buttonStyle(MosaicSecondaryButtonStyle())
            }
        }
    }

    private var orderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Use the arrows to arrange the photos in story order.").foregroundStyle(MosaicTheme.muted)
            ForEach(Array(project.selection.orderedPhotoIDs.enumerated()), id: \.element) { index, id in
                if let photo = photos.first(where: { $0.id == id }) {
                    HStack(spacing: 14) {
                        Text("\(index + 1)").font(.headline).frame(width: 28)
                        PhotoThumbnail(photo: photo).frame(width: 64, height: 82)
                        Text(photo.capturedAt.formatted(date: .omitted, time: .shortened))
                        Spacer()
                        VStack {
                            Button("Move earlier", systemImage: "chevron.up") { move(index, -1) }
                                .frame(minWidth: 44, minHeight: 44)
                                .disabled(index == 0)
                                .accessibilityIdentifier("recap.moveEarlier.\(index)")
                            Button("Move later", systemImage: "chevron.down") { move(index, 1) }
                                .frame(minWidth: 44, minHeight: 44)
                                .disabled(index == project.selection.orderedPhotoIDs.count - 1)
                                .accessibilityIdentifier("recap.moveLater.\(index)")
                        }.labelStyle(.iconOnly)
                    }.porcelainCard()
                }
            }
            Button("Choose style") { stage = .style }.buttonStyle(MosaicPrimaryButtonStyle())
        }
    }

    private var styleView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Template").font(.headline)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { templateChoices(expanded: true) }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) { templateChoices(expanded: false) }
                }.scrollIndicators(.hidden)
            }
            Text("Music").font(.headline)
            VStack(spacing: 8) {
                ForEach(PhotoRecapMusic.allCases) { music in
                    Button { project.music = music } label: {
                        HStack(spacing: 12) {
                            Image(systemName: project.music == music ? "waveform.circle.fill" : "waveform.circle")
                                .font(.title2).foregroundStyle(project.music == music ? MosaicTheme.accentForeground : MosaicTheme.muted)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(music.title).font(.subheadline.weight(.semibold)).foregroundStyle(MosaicTheme.ink)
                                Text(music.artist)
                                    .font(.caption)
                                    .foregroundStyle(MosaicTheme.muted)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            if project.music == music { Image(systemName: "checkmark").foregroundStyle(MosaicTheme.accentForeground) }
                        }
                        .padding(12)
                        .background(project.music == music ? MosaicTheme.sky.opacity(0.15) : MosaicTheme.raisedPaper, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(project.music == music ? .isSelected : [])
                }
            }
            Link("\(project.music.license) · Music source", destination: project.music.sourceURL).font(.footnote)
            Slider(value: $project.musicTrimOffset, in: 0...15, step: 0.5) { Text("Music start") }
            Text("Starts at \(project.musicTrimOffset, format: .number.precision(.fractionLength(1))) seconds").font(.footnote).foregroundStyle(MosaicTheme.muted)
            Button(musicPlayer?.isPlaying == true ? "Stop music preview" : "Preview music", systemImage: musicPlayer?.isPlaying == true ? "stop.fill" : "play.fill") {
                toggleMusicPreview()
            }
            .buttonStyle(MosaicSecondaryButtonStyle())
            .accessibilityIdentifier("recap.music.preview")
            if !project.selection.orderedPhotoIDs.isEmpty {
                Label("About \(durationText) · \(project.selection.orderedPhotoIDs.count) photos", systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("recap.duration")
            }
            Text("Templates affect layout, transitions, grading, and timing only. Reels never add artwork, names, notes, activities, captions, title cards, or statistics.")
                .font(.footnote).foregroundStyle(MosaicTheme.muted)
            Button("Preview recap") { stage = .preview }.buttonStyle(MosaicPrimaryButtonStyle())
        }.porcelainCard()
    }

    @ViewBuilder
    private func templateChoices(expanded: Bool) -> some View {
        ForEach(PhotoRecapTemplate.allCases) { template in
            Button { project.template = template } label: {
                RecapTemplateCard(
                    template: template,
                    selected: project.template == template,
                    previewPhotos: previewPhotos,
                    expanded: expanded
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recap.template.\(template.rawValue)")
            .accessibilityAddTraits(project.template == template ? .isSelected : [])
        }
    }

    private var previewPhotos: [EventPhoto] {
        let ordered = project.selection.orderedPhotoIDs.compactMap { id in
            photos.first(where: { $0.id == id })
        }
        return Array((ordered.isEmpty ? photos : ordered).prefix(3))
    }

    private var previewView: some View {
        VStack(spacing: 16) {
            if let exportURL {
                VideoPlayer(player: AVPlayer(url: exportURL)).frame(height: 470)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityLabel("Rendered photo recap preview")
            } else {
                RecapPlaybackPreview(project: project, photos: orderedSelectedPhotos)
            }
            if isExporting {
                ProgressView(value: exportProgress) { Text("Rendering on this device…") }
                Button("Cancel render", role: .cancel) { renderTask?.cancel() }
                    .buttonStyle(MosaicSecondaryButtonStyle())
                    .accessibilityIdentifier("recap.render.cancel")
            } else if let exportURL {
                ShareLink(item: exportURL) { Label("Share recap", systemImage: "square.and.arrow.up") }.buttonStyle(MosaicPrimaryButtonStyle())
                Button("Save to Photos") { Task { await saveToPhotos(exportURL) } }.buttonStyle(MosaicSecondaryButtonStyle())
            } else {
                Button("Render recap") { startRender() }.buttonStyle(MosaicPrimaryButtonStyle())
            }
            if !project.selection.orderedPhotoIDs.isEmpty {
                Text("Estimated length: \(durationText)")
                    .font(.footnote).foregroundStyle(MosaicTheme.muted)
            }
            Text("Photo details stay in the gallery and never appear in the video.").font(.footnote).foregroundStyle(MosaicTheme.muted)
        }
    }

    private var orderedSelectedPhotos: [EventPhoto] {
        project.selection.orderedPhotoIDs.compactMap { id in photos.first(where: { $0.id == id }) }
    }

    private func selectionLabel(_ photo: EventPhoto) -> String {
        if let index = project.selection.orderedPhotoIDs.firstIndex(of: photo.id) { "Selected photo, position \(index + 1)" }
        else { "Unselected photo" }
    }
    private func move(_ index: Int, _ offset: Int) {
        let destination = index + offset
        guard project.selection.orderedPhotoIDs.indices.contains(destination) else { return }
        project.selection.move(from: IndexSet(integer: index), to: offset > 0 ? destination + 1 : destination)
    }
    private var durationText: String {
        let seconds = max(0, Int(project.estimatedDuration.rounded()))
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
    }
    private func startRender() {
        renderTask?.cancel()
        renderTask = Task { await render() }
    }
    private func render() async {
        isExporting = true; feedback = nil; exportProgress = 0
        defer { isExporting = false; renderTask = nil }
        do {
            exportURL = try await renderer.render(project: project, available: photos) { value in
                Task { @MainActor in exportProgress = value }
            }
        } catch is CancellationError {
            feedback = .init(message: "Rendering cancelled. Your recap draft is still saved.", kind: .information)
        } catch {
            feedback = .init(message: error.localizedDescription, kind: .error)
        }
    }
    private func restoreDraftIfNeeded() {
        guard !loadedDraft else { return }
        loadedDraft = true
        guard shouldRestoreDraft, let saved = model.creativeDrafts.recapProject(for: eventID) else { return }
        project = saved
        if let rawStage = model.creativeDrafts.recapStage(for: eventID), let savedStage = Stage(rawValue: rawStage) {
            stage = savedStage
        }
        feedback = .init(message: "Your recap draft is right where you left it.", kind: .information)
    }
    private func saveDraft() {
        guard loadedDraft else { return }
        model.creativeDrafts.saveRecap(project, stage: stage.rawValue)
    }
    private func resetProject() {
        renderTask?.cancel()
        stopMusicPreview()
        model.creativeDrafts.clearRecap(for: eventID)
        project = PhotoRecapProject(mosaicID: eventID)
        stage = .select
        exportURL = nil
        exportProgress = 0
        feedback = .init(message: "Recap cleared. Choose a fresh set of photos.", kind: .information)
    }
    private func toggleMusicPreview() {
        if musicPlayer?.isPlaying == true {
            stopMusicPreview()
            return
        }
        guard let url = Bundle.main.url(forResource: project.music.rawValue, withExtension: "mp3", subdirectory: "Music")
                ?? Bundle.main.url(forResource: project.music.rawValue, withExtension: "mp3") else {
            feedback = .init(message: "This music preview is unavailable.", kind: .error)
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.currentTime = min(project.musicTrimOffset, max(0, player.duration - 0.1))
            player.prepareToPlay()
            player.play()
            musicPlayer = player
            musicPreviewTask?.cancel()
            musicPreviewTask = Task {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                stopMusicPreview()
            }
        } catch {
            feedback = .init(message: "This music preview is unavailable.", kind: .error)
        }
    }
    private func stopMusicPreview() {
        musicPreviewTask?.cancel()
        musicPreviewTask = nil
        musicPlayer?.stop()
        musicPlayer = nil
    }
    private func saveToPhotos(_ url: URL) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            feedback = .init(message: "Allow Add Photos access to save this recap.", kind: .error)
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            feedback = .init(message: "Saved to Photos.", kind: .success)
        } catch { feedback = .init(message: error.localizedDescription, kind: .error) }
    }
}

private struct RecapPlaybackPreview: View {
    let project: PhotoRecapProject
    let photos: [EventPhoto]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var isPlaying = false

    private var currentPhoto: EventPhoto? {
        guard photos.indices.contains(index) else { return nil }
        return photos[index]
    }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack {
                    previewBackground
                    if let currentPhoto {
                        templateFrame(currentPhoto)
                            .id(currentPhoto.id)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.015)))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
            .aspectRatio(9 / 16, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: 470)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(MosaicTheme.border) }
            .animation(.easeInOut(duration: reduceMotion ? 0.15 : 0.45), value: index)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Photo-only recap preview, frame \(min(index + 1, photos.count)) of \(photos.count)")
            .accessibilityIdentifier("recap.playback.frame")

            HStack(spacing: 12) {
                Button {
                    index = max(0, index - 1)
                    isPlaying = false
                } label: {
                    Image(systemName: "backward.fill").frame(width: 44, height: 44)
                }
                .disabled(index == 0)
                .accessibilityLabel("Previous photo")

                Button {
                    isPlaying.toggle()
                } label: {
                    Label(isPlaying ? "Pause preview" : "Play preview", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .font(.body.weight(.semibold))
                        .frame(minHeight: 44)
                        .padding(.horizontal, 16)
                        .foregroundStyle(MosaicTheme.ink)
                        .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MosaicTheme.border) }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("recap.playback.toggle")

                Button {
                    guard !photos.isEmpty else { return }
                    index = min(photos.count - 1, index + 1)
                    isPlaying = false
                } label: {
                    Image(systemName: "forward.fill").frame(width: 44, height: 44)
                }
                .disabled(index >= photos.count - 1)
                .accessibilityLabel("Next photo")
            }
            Text("Frame \(min(index + 1, photos.count)) of \(photos.count) · \(project.template.secondsPerPhoto, format: .number.precision(.fractionLength(1)))s each")
                .font(.footnote)
                .foregroundStyle(MosaicTheme.muted)
                .contentTransition(.numericText())
        }
        .task(id: isPlaying) {
            guard isPlaying, !photos.isEmpty else { return }
            while !Task.isCancelled, isPlaying {
                try? await Task.sleep(for: .seconds(project.template.secondsPerPhoto))
                guard !Task.isCancelled, isPlaying else { return }
                if index + 1 < photos.count {
                    index += 1
                } else {
                    index = 0
                    isPlaying = false
                }
            }
        }
        .onChange(of: project.selection.orderedPhotoIDs) { _, _ in index = 0; isPlaying = false }
        .onDisappear { isPlaying = false }
    }

    @ViewBuilder
    private func templateFrame(_ photo: EventPhoto) -> some View {
        switch project.template {
        case .porcelainPrint:
            PhotoThumbnail(photo: photo)
                .padding(10)
                .padding(.bottom, 18)
                .background(.white)
                .padding(22)
                .rotationEffect(.degrees(-0.6))
                .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
        case .kilnTape:
            PhotoThumbnail(photo: photo)
                .overlay(MosaicTheme.gold.opacity(0.12).blendMode(.softLight))
        case .pocketKiln:
            PhotoThumbnail(photo: photo)
                .padding(22)
                .overlay { Rectangle().stroke(.white.opacity(0.3), lineWidth: 1).padding(22) }
        }
    }

    private var previewBackground: Color {
        switch project.template {
        case .porcelainPrint: MosaicTheme.porcelain
        case .kilnTape: .black
        case .pocketKiln: MosaicTheme.ink
        }
    }
}

private struct RecapTemplateCard: View {
    let template: PhotoRecapTemplate
    let selected: Bool
    let previewPhotos: [EventPhoto]
    var expanded = false

    var body: some View {
        Group {
            if expanded {
                HStack(spacing: 14) {
                    thumbnail.frame(width: 88, height: 128)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(template.title).font(.headline).foregroundStyle(MosaicTheme.ink)
                        Text(template.detail).font(.body).foregroundStyle(MosaicTheme.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(MosaicTheme.raisedPaper, in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    thumbnail.frame(width: 126, height: 190)
                    Text(template.title).font(.subheadline.weight(.semibold)).foregroundStyle(MosaicTheme.ink)
                    Text(template.detail).font(.caption2).foregroundStyle(MosaicTheme.muted).frame(width: 126, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.title), \(template.detail)")
    }

    private var thumbnail: some View {
        ZStack {
            background
            previewFrame
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(MosaicTheme.porcelain, MosaicTheme.accentForeground)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(selected ? MosaicTheme.accentForeground : MosaicTheme.border, lineWidth: selected ? 3 : 1) }
    }

    @ViewBuilder private var previewFrame: some View {
        switch template {
        case .porcelainPrint:
            recapPhoto(0)
                .frame(width: 92, height: 142)
                .padding(7)
                .padding(.bottom, 10)
                .background(.white)
                .rotationEffect(.degrees(-1.2))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 3)
        case .kilnTape:
            ZStack(alignment: .bottomTrailing) {
                recapPhoto(0)
                recapPhoto(1)
                    .frame(width: 52, height: 72)
                    .overlay { Rectangle().stroke(.white.opacity(0.75), lineWidth: 2) }
                    .padding(8)
            }
            .overlay { Rectangle().fill(MosaicTheme.gold.opacity(0.12)).blendMode(.softLight) }
        case .pocketKiln:
            HStack(spacing: 3) {
                recapPhoto(0)
                VStack(spacing: 3) {
                    recapPhoto(1)
                    recapPhoto(2)
                }
            }
            .padding(6)
        }
    }

    @ViewBuilder
    private func recapPhoto(_ index: Int) -> some View {
        if previewPhotos.indices.contains(index) {
            PhotoThumbnail(photo: previewPhotos[index])
                .clipShape(Rectangle())
        } else {
            LinearGradient(
                colors: [MosaicTheme.clay, MosaicTheme.gold, MosaicTheme.deepGlaze],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var background: Color {
        switch template {
        case .porcelainPrint: MosaicTheme.porcelain
        case .kilnTape: .black
        case .pocketKiln: MosaicTheme.ink
        }
    }
}
