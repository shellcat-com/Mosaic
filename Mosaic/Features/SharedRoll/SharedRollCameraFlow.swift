import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SharedRollCameraFlow: View {
    @Environment(AppStore.self) private var store
    private let startsInViewfinder: Bool

    init(startsInViewfinder: Bool = false) {
        self.startsInViewfinder = startsInViewfinder
    }

    var body: some View {
        if store.challenge.experienceVersion == .kindnessRoll {
            KindnessRollCaptureFlow(
                startsInViewfinder: startsInViewfinder,
                initialMission: startsInViewfinder ? store.missions.first : nil
            )
        } else {
            LegacySharedRollCameraFlow()
        }
    }
}

private struct LegacySharedRollCameraFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(MosaicRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .choose
    @State private var payload: SharedMomentPayload?
    @State private var note = ""
    @State private var category: MissionCategory?
    @State private var exportConsent = false
    @State private var attribution: SharedMomentAttribution = .anonymous
    @State private var photoItem: PhotosPickerItem?
    @State private var videoItem: PhotosPickerItem?
    @State private var showingPhotoCamera = false
    @State private var showingVideoCamera = false
    @State private var isSealing = false
    @State private var mediaError: String?
    @State private var showReminderChoice = false

    private enum Stage { case choose, review, sealed }

    var body: some View {
        Group {
            switch stage {
            case .choose: chooser
            case .review: review
            case .sealed: sealed
            }
        }
        .fullScreenCover(isPresented: $showingPhotoCamera) {
            EvidenceCameraView(challenge: store.challenge, dismissOnUse: true) { data in
                payload = .photo(data)
                stage = .review
            }
        }
        .sheet(isPresented: $showingVideoCamera) {
            PrivateMediaPicker(sourceType: .camera, method: .video) { data, duration in
                guard let duration else { return }
                payload = .video(data, duration: duration)
                stage = .review
            } onError: { message in
                mediaError = message
            }
            .ignoresSafeArea()
        }
        .task(id: photoItem) { await loadPhoto() }
        .task(id: videoItem) { await loadVideo() }
        .confirmationDialog("Set a reminder?", isPresented: $showReminderChoice, titleVisibility: .visible) {
            Button("Set reminder") {
                Task {
                    _ = await LocalMomentReminderService.shared.requestAndSchedule(
                        for: store.challenge.summary,
                        lastActivity: store.lastSealedMomentAt
                    )
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Mosaic can remind you once before contributions close and once when the reveal opens.")
        }
    }

    private var chooser: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    chooserHeader
                    sourcePicker

                    Label {
                        Text("Nothing is visible to the group until the reveal.")
                    } icon: {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(MosaicTheme.indigo)
                    }
                    .font(MosaicTheme.caption(.medium))
                    .foregroundStyle(MosaicTheme.muted)

                    if let mediaError {
                        Label(mediaError, systemImage: "exclamationmark.triangle.fill")
                            .font(MosaicTheme.caption(.medium))
                            .foregroundStyle(MosaicTheme.persimmon)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
            .background(MosaicTheme.canvas)
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    private var chooserHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("PRIVATE UNTIL REVEAL", systemImage: "lock.fill")
                .font(MosaicTheme.caption(.bold))
                .foregroundStyle(MosaicTheme.indigo)
            Text("Add a memory")
                .font(MosaicTheme.display(40, weight: .semibold))
                .foregroundStyle(MosaicTheme.ink)
            Text("Capture one part of \(store.challenge.name) that the group will want to remember.")
                .font(MosaicTheme.body())
                .foregroundStyle(MosaicTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sourcePicker: some View {
        VStack(spacing: 0) {
            sourceSection(
                title: "Photo",
                detail: "Take a new photo or choose one you already have.",
                icon: "camera.fill",
                tint: MosaicTheme.persimmon
            ) {
                HStack(spacing: 8) {
                    Button { showingPhotoCamera = true } label: {
                        Label("Camera", systemImage: "camera")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.persimmon))

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Library", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }

            Divider().padding(.leading, 72)

            sourceSection(
                title: "Video",
                detail: "Add a clip up to 10 seconds.",
                icon: "video.fill",
                tint: MosaicTheme.indigo
            ) {
                HStack(spacing: 8) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showingVideoCamera = true } label: {
                            Label("Record", systemImage: "record.circle")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                    PhotosPicker(selection: $videoItem, matching: .videos) {
                        Label("Library", systemImage: "video.badge.plus")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }

            Divider().padding(.leading, 72)

            Button {
                payload = .note
                stage = .review
            } label: {
                HStack(spacing: 16) {
                    sourceIcon("text.quote", tint: MosaicTheme.sage)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note")
                            .font(MosaicTheme.body(.semibold))
                            .foregroundStyle(MosaicTheme.ink)
                        Text("Save a thought without adding media.")
                            .font(MosaicTheme.caption())
                            .foregroundStyle(MosaicTheme.muted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MosaicTheme.border, lineWidth: 1)
        }
    }

    private func sourceSection<Actions: View>(
        title: String,
        detail: String,
        icon: String,
        tint: Color,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            sourceIcon(icon, tint: tint)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(MosaicTheme.body(.semibold))
                        .foregroundStyle(MosaicTheme.ink)
                    Text(detail)
                        .font(MosaicTheme.caption())
                        .foregroundStyle(MosaicTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                actions()
            }
        }
        .padding(16)
    }

    private func sourceIcon(_ icon: String, tint: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }

    private var review: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    preview

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(payload?.kind == .note ? "Write your memory" : "Add context")
                                .font(MosaicTheme.display(24, weight: .semibold))
                            Text(payload?.kind == .note ? "Keep it short and specific." : "A note is optional, but it helps the moment make sense later.")
                                .font(MosaicTheme.caption())
                                .foregroundStyle(MosaicTheme.muted)
                        }
                        TextField(
                            payload?.kind == .note ? "What happened?" : "Add a note…",
                            text: $note,
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                        .font(MosaicTheme.body())
                        .padding(16)
                        .background(MosaicTheme.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Divider()

                        HStack {
                            Label("Act label", systemImage: "tag")
                                .font(MosaicTheme.body(.medium))
                            Spacer()
                            Picker("Act label", selection: $category) {
                                Text("None").tag(MissionCategory?.none)
                                ForEach(MissionCategory.allCases) { item in
                                    Text(item.title).tag(Optional(item))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(16)
                    .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(MosaicTheme.border, lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .font(.title3)
                                .foregroundStyle(MosaicTheme.indigo)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sharing controls")
                                    .font(MosaicTheme.body(.semibold))
                                Text("The memory stays hidden from the group until reveal.")
                                    .font(MosaicTheme.caption())
                                    .foregroundStyle(MosaicTheme.muted)
                            }
                        }

                        Divider()

                        Toggle(isOn: $exportConsent) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Include in shareable recap")
                                    .font(MosaicTheme.body(.medium))
                                Text("Allows this memory in the exported group video.")
                                    .font(MosaicTheme.caption())
                                    .foregroundStyle(MosaicTheme.muted)
                            }
                        }
                            .tint(MosaicTheme.indigo)

                        Divider()

                        DisclosureGroup("Name and attribution") {
                            Picker("Attribution", selection: $attribution) {
                                Text("Anonymous").tag(SharedMomentAttribution.anonymous)
                                Text("Show my permitted name").tag(SharedMomentAttribution.permitted)
                            }
                            .pickerStyle(.segmented)
                            .padding(.top, 8)
                        }
                        .font(MosaicTheme.body(.medium))
                    }
                    .padding(16)
                    .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(MosaicTheme.border, lineWidth: 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(MosaicTheme.canvas)
            .navigationTitle("Review memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                reviewActions
            }
        }
    }

    private var reviewActions: some View {
        VStack(spacing: 8) {
            Button {
                seal()
            } label: {
                if isSealing {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Adding memory…")
                    }
                } else {
                    Label("Add to Mosaic", systemImage: "checkmark")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canAdd || isSealing)

            HStack {
                Button("Save private draft") {
                    guard let payload else { return }
                    Task {
                        await store.keepPrivateSharedMoment(payload: payload, note: note)
                        dismiss()
                    }
                }
                Spacer()
                Button("Choose another") { resetSelection() }
            }
            .font(MosaicTheme.caption(.semibold))
            .foregroundStyle(MosaicTheme.indigo)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    @ViewBuilder
    private var preview: some View {
        switch payload?.kind {
        case .photo:
            if let data = payload?.data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityLabel("Selected photo")
            }
        case .video:
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MosaicTheme.ink)
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                    Text("Video ready")
                        .font(MosaicTheme.body(.semibold))
                    Text(String(format: "%.1f seconds", payload?.durationSeconds ?? 0))
                        .font(MosaicTheme.caption())
                        .foregroundStyle(.white.opacity(0.72))
                }
                .foregroundStyle(.white)
            }
            .frame(height: 220)
            .accessibilityElement(children: .combine)
        case .note:
            HStack(spacing: 16) {
                sourceIcon("text.quote", tint: MosaicTheme.sage)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Text memory")
                        .font(MosaicTheme.display(24, weight: .semibold))
                    Text("Your note becomes a card in the reveal.")
                        .font(MosaicTheme.caption())
                        .foregroundStyle(MosaicTheme.muted)
                }
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MosaicTheme.border, lineWidth: 1)
            }
        case nil:
            EmptyView()
        }
    }

    private var sealed: some View {
        ZStack {
            MosaicTheme.canvas.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(MosaicTheme.sage, in: Circle())
                Text("Memory added")
                    .font(MosaicTheme.display(36, weight: .semibold))
                Text(exportConsent
                     ? "It stays private until reveal and can be included in the group recap."
                     : "It stays private until the group reveal.")
                    .font(MosaicTheme.body())
                    .foregroundStyle(MosaicTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        router.finishFlow(at: .groups)
                    } label: {
                        Label("View my Mosaic", systemImage: "square.grid.2x2.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.sage))

                    Button {
                        router.finishFlow(at: .groups)
                    } label: {
                        Label("Back to home", systemImage: "house.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle(color: MosaicTheme.indigo))
                }
            }
            .padding(24)
        }
    }

    private var canAdd: Bool {
        guard let payload else { return false }
        if payload.kind == .note {
            return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return payload.data != nil
    }

    private func loadPhoto() async {
        guard let photoItem else { return }
        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self), UIImage(data: data) != nil else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let look = store.challenge.filmLookID
            let developed = await Task.detached(priority: .userInitiated) {
                DisposableCameraFilter.developJPEG(data, look: look)
            }.value
            payload = .photo(developed ?? data)
            mediaError = nil
            stage = .review
        } catch {
            mediaError = "That photo could not be prepared. Choose another photo."
        }
    }

    private func loadVideo() async {
        guard let videoItem else { return }
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mosaic-memory-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        do {
            guard let data = try await videoItem.loadTransferable(type: Data.self) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try data.write(to: temporaryURL, options: .atomic)
            let duration = try await AVURLAsset(url: temporaryURL).load(.duration).seconds
            try EvidenceUploadPolicy.validate(method: .video, byteCount: data.count, duration: duration)
            let mimeType = videoItem.supportedContentTypes
                .first(where: { $0.conforms(to: .movie) })?
                .preferredMIMEType ?? "video/quicktime"
            payload = .video(data, duration: duration, mimeType: mimeType)
            mediaError = nil
            stage = .review
        } catch {
            mediaError = error.localizedDescription
        }
    }

    private func resetSelection() {
        payload = nil
        note = ""
        photoItem = nil
        videoItem = nil
        mediaError = nil
        stage = .choose
    }

    private func seal() {
        guard let payload, canAdd else { return }
        isSealing = true
        Task {
            let firstMoment = store.challenge.sharedMoments.isEmpty
            if await store.sealSharedMoment(
                payload: payload,
                note: note,
                category: category,
                exportConsent: exportConsent,
                attribution: attribution
            ) != nil {
                withAnimation(.easeInOut(duration: 0.3)) { stage = .sealed }
                if firstMoment { showReminderChoice = true }
            }
            isSealing = false
        }
    }
}

private struct KindnessRollCaptureFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(MosaicRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stage: Stage = .mission
    @State private var mission: Mission?
    @State private var payload: SharedMomentPayload?
    @State private var caption = ""
    @State private var exportConsent = false
    @State private var photoItem: PhotosPickerItem?
    @State private var videoItem: PhotosPickerItem?
    @State private var showingPhotoCamera = false
    @State private var showingVideoCamera = false
    @State private var isSealing = false
    @State private var errorMessage: String?
    @State private var captureMode: CaptureMode = .photo

    private enum Stage { case mission, capture, review, settling }
    private enum CaptureMode: String, CaseIterable, Identifiable {
        case photo = "Photo"
        case video = "Video"
        case note = "Note"

        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .photo: "camera.fill"
            case .video: "video.fill"
            case .note: "text.quote"
            }
        }
    }

    init(startsInViewfinder: Bool = false, initialMission: Mission? = nil) {
        _stage = State(initialValue: startsInViewfinder ? .capture : .mission)
        _mission = State(initialValue: initialMission)
    }

    var body: some View {
        ZStack {
            MosaicTheme.canvas.ignoresSafeArea()
            switch stage {
            case .mission: missionPicker
            case .capture: disposableCamera
            case .review: review
            case .settling: settling
            }
        }
        .foregroundStyle(MosaicTheme.ink)
        .tint(MosaicTheme.indigo)
        .fullScreenCover(isPresented: $showingPhotoCamera) {
            EvidenceCameraView(challenge: store.challenge, dismissOnUse: true) { data in
                payload = .photo(data)
                stage = .review
            }
        }
        .sheet(isPresented: $showingVideoCamera) {
            PrivateMediaPicker(sourceType: .camera, method: .video) { data, duration in
                guard let duration else { return }
                payload = .video(data, duration: duration)
                stage = .review
            } onError: { errorMessage = $0 }
            .ignoresSafeArea()
        }
        .task(id: photoItem) { await loadPhoto() }
        .task(id: videoItem) { await loadVideo() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MosaicTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(MosaicTheme.paper, in: Circle())
                    .overlay { Circle().stroke(MosaicTheme.border, lineWidth: 1) }
            }
            .accessibilityLabel("Close camera")
            VStack(alignment: .leading, spacing: 2) {
                Text(store.challenge.name)
                    .font(MosaicTheme.body(.semibold))
                    .foregroundStyle(MosaicTheme.ink)
                    .lineLimit(1)
                Text("KINDNESS ROLL · \(store.challenge.filmLookID.title.uppercased())")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(MosaicTheme.muted)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MosaicTheme.indigo)
                .frame(width: 44, height: 44)
                .background(MosaicTheme.indigo.opacity(0.1), in: Circle())
                .accessibilityLabel("Private until reveal")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var missionPicker: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CHOOSE AN ACT")
                            .font(MosaicTheme.caption(.bold))
                            .tracking(1.2)
                            .foregroundStyle(MosaicTheme.indigo)
                        Text("What did you do?")
                            .font(MosaicTheme.display(36, weight: .semibold))
                        Text("Pick the act that belongs to this moment. Each act becomes one piece of the group Mosaic.")
                            .font(MosaicTheme.body())
                            .foregroundStyle(MosaicTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let mission {
                        HStack(spacing: 20) {
                            CeramicTile(
                                category: mission.category,
                                emotion: .caring,
                                evidence: mission.evidence.first ?? .reflection,
                                size: 104
                            )
                            .rotationEffect(.degrees(reduceMotion ? 0 : -2))

                            VStack(alignment: .leading, spacing: 8) {
                                Label("YOUR TILE", systemImage: mission.category.symbol)
                                    .font(MosaicTheme.caption(.bold))
                                    .foregroundStyle(MosaicTheme.indigo)
                                Text(mission.title)
                                    .font(MosaicTheme.display(25, weight: .semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(mission.minutes) min · \(mission.effort)")
                                    .font(MosaicTheme.caption(.medium))
                                    .foregroundStyle(MosaicTheme.muted)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MosaicTheme.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(MosaicTheme.indigo.opacity(0.18), lineWidth: 1)
                        }
                        .transition(.opacity)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("ALL ACTS")
                            .font(MosaicTheme.caption(.bold))
                            .tracking(1.2)
                            .foregroundStyle(MosaicTheme.muted)

                        VStack(spacing: 0) {
                            ForEach(Array(store.missions.enumerated()), id: \.element.id) { index, item in
                                if index > 0 { Divider().padding(.leading, 64) }
                                missionRow(item)
                            }
                        }
                        .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(MosaicTheme.border, lineWidth: 1)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear { if mission == nil { mission = store.missions.first } }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                guard mission != nil else { return }
                withAnimation(.easeInOut(duration: 0.24)) { stage = .capture }
            } label: {
                Label("Continue with this act", systemImage: "arrow.right")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(mission == nil)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(MosaicTheme.porcelain.opacity(0.97))
        }
    }

    private func missionRow(_ item: Mission) -> some View {
        let isSelected = mission?.id == item.id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { mission = item }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.category.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : MosaicTheme.indigo)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? MosaicTheme.indigo : MosaicTheme.indigo.opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(MosaicTheme.body(.semibold))
                        .foregroundStyle(MosaicTheme.ink)
                    Text(item.detail)
                        .font(MosaicTheme.caption())
                        .foregroundStyle(MosaicTheme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? MosaicTheme.indigo : MosaicTheme.border)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var disposableCamera: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let mission {
                        HStack(spacing: 16) {
                            CeramicTile(
                                category: mission.category,
                                emotion: .caring,
                                evidence: mission.evidence.first ?? .reflection,
                                size: 88
                            )
                            VStack(alignment: .leading, spacing: 6) {
                                Text("READY TO ADD")
                                    .font(MosaicTheme.caption(.bold))
                                    .tracking(1.2)
                                    .foregroundStyle(MosaicTheme.indigo)
                                Text(mission.title)
                                    .font(MosaicTheme.display(27, weight: .semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("Choose a different act") { stage = .mission }
                                    .font(MosaicTheme.caption(.semibold))
                                    .foregroundStyle(MosaicTheme.indigo)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(20)
                        .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(MosaicTheme.border, lineWidth: 1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("SAVE THE MOMENT")
                            .font(MosaicTheme.caption(.bold))
                            .tracking(1.2)
                            .foregroundStyle(MosaicTheme.indigo)
                        Text("How do you want to remember it?")
                            .font(MosaicTheme.display(34, weight: .semibold))
                        Text("Choose one simple format. You’ll review exactly what is saved before creating your tile.")
                            .font(MosaicTheme.body())
                            .foregroundStyle(MosaicTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 4) {
                        ForEach(CaptureMode.allCases) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { captureMode = mode }
                            } label: {
                                Label(mode.rawValue, systemImage: mode.symbol)
                                    .font(MosaicTheme.caption(.bold))
                                    .labelStyle(.titleAndIcon)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .foregroundStyle(captureMode == mode ? Color.white : MosaicTheme.muted)
                                    .background(captureMode == mode ? MosaicTheme.indigo : Color.clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(captureMode == mode ? .isSelected : [])
                        }
                    }
                    .padding(4)
                    .background(MosaicTheme.paper, in: Capsule())
                    .overlay { Capsule().stroke(MosaicTheme.border, lineWidth: 1) }

                    captureModePanel

                    Label("Your contribution stays private until the group reveal.", systemImage: "lock.shield.fill")
                        .font(MosaicTheme.caption(.semibold))
                        .foregroundStyle(MosaicTheme.indigo)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MosaicTheme.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(MosaicTheme.caption(.medium))
                            .foregroundStyle(MosaicTheme.persimmon)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var captureModePanel: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: captureMode.symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(captureMode == .video ? MosaicTheme.persimmon : MosaicTheme.indigo)
                    .frame(width: 64, height: 64)
                    .background(
                        (captureMode == .video ? MosaicTheme.persimmon : MosaicTheme.indigo).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                Text(captureModeTitle)
                    .font(MosaicTheme.display(27, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text(captureModeDetail)
                    .font(MosaicTheme.body())
                    .foregroundStyle(MosaicTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch captureMode {
            case .photo:
                Button { showingPhotoCamera = true } label: {
                    Label("Take a photo", systemImage: "camera.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Open photo camera")
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Choose from library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            case .video:
                Button { showingVideoCamera = true } label: {
                    Label("Record up to 10 seconds", systemImage: "record.circle")
                }
                .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.persimmon))
                .accessibilityLabel("Record a ten second video")
                PhotosPicker(selection: $videoItem, matching: .videos) {
                    Label("Choose from library", systemImage: "video.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            case .note:
                Button {
                    payload = .note
                    stage = .review
                } label: {
                    Label("Write a private note", systemImage: "square.and.pencil")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Write a note")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(MosaicTheme.border, lineWidth: 1)
        }
    }

    private var captureModeTitle: String {
        switch captureMode {
        case .photo: "Photograph the moment"
        case .video: "Record a short glimpse"
        case .note: "Keep it in words"
        }
    }

    private var captureModeDetail: String {
        switch captureMode {
        case .photo: "Capture something meaningful without including faces or private details."
        case .video: "Save one quiet, ten-second detail from the act."
        case .note: "Write a short reflection when the story matters more than a picture."
        }
    }

    private var review: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REVIEW YOUR MOMENT")
                            .font(MosaicTheme.caption(.bold))
                            .tracking(1.2)
                            .foregroundStyle(MosaicTheme.indigo)
                        Text("Keep the proof private.")
                            .font(MosaicTheme.display(34, weight: .semibold))
                        Text("Check exactly what will be saved, then choose whether this moment may appear in a shareable recap.")
                            .font(MosaicTheme.body())
                            .foregroundStyle(MosaicTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    mediaPreview

                    VStack(alignment: .leading, spacing: 12) {
                        Label(payload?.kind == .note ? "YOUR NOTE" : "ADD A NOTE", systemImage: "text.quote")
                            .font(MosaicTheme.caption(.bold))
                            .tracking(1.2)
                            .foregroundStyle(MosaicTheme.indigo)

                        TextField(
                            payload?.kind == .note ? "What would you like to remember?" : "Optional context for this moment",
                            text: $caption,
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                        .font(MosaicTheme.body())
                        .padding(16)
                        .foregroundStyle(MosaicTheme.ink)
                        .background(MosaicTheme.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(16)
                    .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(MosaicTheme.border, lineWidth: 1)
                    }

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(MosaicTheme.indigo)
                                .frame(width: 44, height: 44)
                                .background(MosaicTheme.indigo.opacity(0.1), in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Evidence")
                                    .font(MosaicTheme.body(.semibold))
                                Text("Organizer only")
                                    .font(MosaicTheme.caption())
                                    .foregroundStyle(MosaicTheme.muted)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(MosaicTheme.sage)
                        }
                        .padding(16)

                        Divider().padding(.leading, 72)

                        Toggle(isOn: $exportConsent) {
                            HStack(spacing: 12) {
                                Image(systemName: "heart")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(MosaicTheme.persimmon)
                                    .frame(width: 44, height: 44)
                                    .background(MosaicTheme.persimmon.opacity(0.1), in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Include this memory")
                                        .font(MosaicTheme.body(.semibold))
                                    Text("Allow it in a shareable recap")
                                        .font(MosaicTheme.caption())
                                        .foregroundStyle(MosaicTheme.muted)
                                }
                            }
                        }
                        .tint(MosaicTheme.indigo)
                        .padding(16)
                    }
                    .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(MosaicTheme.border, lineWidth: 1)
                    }

                    Text("Evidence stays private even if you include the memory. Only the selected story permission changes.")
                        .font(MosaicTheme.caption())
                        .foregroundStyle(MosaicTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(MosaicTheme.caption(.medium))
                            .foregroundStyle(MosaicTheme.persimmon)
                    }
                }
                .padding(20)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 12) {
                Button("Retake") { resetCapture() }
                    .buttonStyle(SecondaryButtonStyle())
                Button {
                    seal()
                } label: {
                    if isSealing { ProgressView().tint(.white) }
                    else { Label("Create my tile", systemImage: "seal.fill") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSeal || isSealing)
                .opacity(canSeal && !isSealing ? 1 : 0.45)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(MosaicTheme.porcelain.opacity(0.97))
        }
    }

    @ViewBuilder
    private var mediaPreview: some View {
        switch payload?.kind {
        case .photo:
            if let data = payload?.data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(MosaicTheme.border, lineWidth: 1)
                    }
                    .accessibilityLabel("Captured photo preview")
                    .overlay(alignment: .topLeading) {
                        Label("\(store.challenge.filmLookID.title) film", systemImage: "camera.aperture")
                            .font(MosaicTheme.caption(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.58), in: Capsule())
                            .padding(14)
                    }
            }
        case .video:
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous).fill(MosaicTheme.claySurface)
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(MosaicTheme.persimmon)
                    Text("Video ready").font(MosaicTheme.body(.semibold))
                    Text(String(format: "%.1f seconds", payload?.durationSeconds ?? 0))
                        .font(MosaicTheme.caption()).foregroundStyle(MosaicTheme.muted)
                }
            }
            .frame(height: 300)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(MosaicTheme.border, lineWidth: 1)
            }
        case .note:
            VStack(spacing: 12) {
                MosaicSticker(kind: .kindNote, size: 72)
                Text("A note can hold the whole moment.")
                    .font(MosaicTheme.display(25, weight: .semibold))
                Text("Write a few words below. They stay sealed with your tile until the reveal.")
                    .font(MosaicTheme.body()).multilineTextAlignment(.center)
                    .foregroundStyle(MosaicTheme.muted)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 240)
            .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(MosaicTheme.border, lineWidth: 1)
            }
        case nil:
            EmptyView()
        }
    }

    private var settling: some View {
        VStack(spacing: 20) {
            Spacer()
            if let mission {
                CeramicTile(
                    category: mission.category,
                    emotion: .caring,
                    evidence: mission.evidence.first ?? .reflection,
                    size: 148
                )
                .rotationEffect(.degrees(reduceMotion ? 0 : -3))
                .shadow(color: MosaicTheme.indigo.opacity(0.18), radius: 24, y: 12)
            }
            Text("Your tile is set")
                .font(MosaicTheme.display(36, weight: .semibold))
            Text("The moment is sealed until everyone reveals together.")
                .font(MosaicTheme.body())
                .foregroundStyle(MosaicTheme.muted)
                .multilineTextAlignment(.center)
            Label("PRIVATE UNTIL REVEAL", systemImage: "lock.fill")
                .font(MosaicTheme.caption(.bold))
                .tracking(1.2)
                .foregroundStyle(MosaicTheme.indigo)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(MosaicTheme.indigo.opacity(0.08), in: Capsule())
            Spacer()
        }
        .padding(32)
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 1_250))
            router.finishFlow(at: .groups)
        }
    }

    private var canSeal: Bool {
        guard let payload else { return false }
        return payload.kind != .note || !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadPhoto() async {
        guard let photoItem else { return }
        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self), UIImage(data: data) != nil else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try EvidenceUploadPolicy.validate(method: .photo, byteCount: data.count, duration: nil)
            let look = store.challenge.filmLookID
            let developed = await Task.detached(priority: .userInitiated) {
                DisposableCameraFilter.developJPEG(data, look: look)
            }.value
            payload = .photo(developed ?? data)
            errorMessage = nil
            stage = .review
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadVideo() async {
        guard let videoItem else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kindness-roll-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            guard let data = try await videoItem.loadTransferable(type: Data.self) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try data.write(to: url, options: .atomic)
            let duration = try await AVURLAsset(url: url).load(.duration).seconds
            try EvidenceUploadPolicy.validate(method: .video, byteCount: data.count, duration: duration)
            let mime = videoItem.supportedContentTypes.first(where: { $0.conforms(to: .movie) })?.preferredMIMEType
                ?? "video/quicktime"
            payload = .video(data, duration: duration, mimeType: mime)
            errorMessage = nil
            stage = .review
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetCapture() {
        payload = nil
        caption = ""
        photoItem = nil
        videoItem = nil
        errorMessage = nil
        stage = .capture
    }

    private func seal() {
        guard let mission, let payload, canSeal else { return }
        isSealing = true
        Task {
            if await store.sealKindnessAct(
                mission: mission,
                payload: payload,
                caption: caption,
                exportConsent: exportConsent
            ) != nil {
                if reduceMotion { stage = .settling }
                else { withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { stage = .settling } }
            } else {
                errorMessage = store.backendMessage
            }
            isSealing = false
        }
    }
}
