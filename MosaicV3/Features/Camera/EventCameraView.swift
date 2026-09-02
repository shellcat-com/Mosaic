import SwiftUI

struct EventCameraView: View {
    @Environment(MosaicAppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller = CameraCaptureController()
    @State private var message: String?
    @State private var isCapturing = false
    @State private var captureFeedbackCount = 0

    var body: some View {
        VStack(spacing: 0) {
            if let event = model.camera.selectedEvent {
                eventPicker
                if let jpeg = model.camera.reviewJPEG {
                    PhotoReviewView(jpeg: jpeg, look: event.filmLookID, retake: model.camera.retake) {
                        Task { await keepReview() }
                    }
                } else {
                    cameraBody(event)
                }
            } else {
                ContentUnavailableView("Choose an active Mosaic", systemImage: "camera", description: Text("Join or create a Mosaic before opening its disposable camera."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityHidden(isCapturing)
        .porcelainBackground()
        .navigationTitle("Camera")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await start()
            await model.camera.restorePendingPhotos()
            await model.camera.retryPendingUploads()
        }
        .onDisappear { controller.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await start() }
            } else if phase == .background {
                controller.stop()
            }
        }
        .onAppear {
            if let requestedID = model.router.consumeCameraRequest(),
               let requested = model.library.active.first(where: { $0.id == requestedID && $0.phase.acceptsPhotos }) {
                model.camera.select(requested)
            } else if model.camera.selectedEvent == nil {
                model.camera.select(model.library.active.first(where: { $0.phase.acceptsPhotos }))
            }
        }
        .mosaicAccessibilityAnnouncement(message ?? model.camera.message)
        .overlay {
            if isCapturing, let event = model.camera.selectedEvent {
                FilmDevelopmentOverlay(look: event.filmLookID)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isCapturing)
        .sensoryFeedback(.impact(weight: .medium), trigger: captureFeedbackCount)
    }

    private var eventPicker: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Menu {
                    ForEach(availableEvents) { event in
                        Button(event.name) { selectEvent(event.id) }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundStyle(MosaicTheme.accentForeground)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Camera Mosaic")
                                .font(.caption)
                                .foregroundStyle(MosaicTheme.muted)
                            Text(model.camera.selectedEvent?.name ?? "Choose a Mosaic")
                                .font(.headline)
                                .foregroundStyle(MosaicTheme.ink)
                                .lineLimit(3)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(MosaicTheme.muted)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: MosaicTheme.minimumHitTarget, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("camera.eventPicker.accessibility")
                }
                .accessibilityLabel("Camera Mosaic, \(model.camera.selectedEvent?.name ?? "none selected")")
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundStyle(MosaicTheme.accentForeground)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LOADED MOSAIC")
                            .font(.caption2.bold())
                            .tracking(1.1)
                            .foregroundStyle(MosaicTheme.muted)
                        Picker("Mosaic camera", selection: eventSelection) {
                            ForEach(availableEvents) { event in
                                Text(event.name).tag(Optional(event.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(MosaicTheme.ink)
                        .accessibilityIdentifier("camera.eventPicker.standard")
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(MosaicTheme.muted)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 12 : 0)
        .frame(minHeight: 58)
        .background(MosaicTheme.paper)
    }

    private var availableEvents: [MosaicSummary] {
        model.library.active.filter { $0.phase.acceptsPhotos }
    }

    private var eventSelection: Binding<UUID?> {
        Binding(
            get: { model.camera.selectedEvent?.id },
            set: { newValue in selectEvent(newValue) }
        )
    }

    private func selectEvent(_ id: UUID?) {
        model.camera.select(availableEvents.first { $0.id == id })
        Task {
            await model.camera.restorePendingPhotos()
            await model.camera.retryPendingUploads()
        }
    }

    private func cameraBody(_ event: MosaicSummary) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                DisposableCameraShell(event: event, shotsRemaining: model.camera.shotsRemaining) {
                    CameraPreview(session: controller.session)
                }
                if controller.permissionDenied {
                    VStack(spacing: 10) {
                        Text("Camera access is off").font(.headline)
                        Text("Enable Camera in Settings to use this Mosaic's disposable roll.").font(.subheadline).foregroundStyle(MosaicTheme.muted)
                        Button("Open Settings") {
                            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(settingsURL)
                        }
                    }.porcelainCard()
                } else {
                    Button { Task { await capture() } } label: { CameraShutter() }
                    .frame(minWidth: 82, minHeight: 82)
                    .disabled(!model.camera.canCapture || !controller.isReady)
                    .accessibilityLabel("Take photo, \(model.camera.shotsRemaining) shots remaining")
                    .accessibilityIdentifier("camera.shutter")
                }
                if let message = message ?? model.camera.message { Text(message).font(.footnote).foregroundStyle(.red) }
                SealedRollView(photos: model.camera.ownPhotos) { photo in
                    Task { await delete(photo) }
                }
            }.padding(20)
        }.scrollIndicators(.hidden)
    }

    private func start() async {
        do { try await controller.start(); message = nil }
        catch { message = error.localizedDescription }
    }

    private func capture() async {
        guard !isCapturing else { return }
        isCapturing = true
        captureFeedbackCount += 1
        defer { isCapturing = false }
        do {
            let data = try await controller.capture()
            await model.camera.prepareReview(rawPhotoData: data)
        } catch { message = error.localizedDescription }
    }

    private func keepReview() async {
        do {
            try await model.camera.keepReview()
            message = model.camera.message
        } catch {
            message = model.camera.message ?? error.localizedDescription
        }
    }

    private func delete(_ photo: EventPhoto) async {
        do {
            try await model.camera.delete(photo)
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }
}

struct PhotoReviewView: View {
    let jpeg: Data
    let look: FilmLookID
    let retake: () -> Void
    let keep: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasDeveloped = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("DEVELOPED · \(look.title.uppercased())")
                    .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(MosaicTheme.clay)
                if let image = UIImage(data: jpeg) {
                    Image(uiImage: image).resizable().scaledToFit().padding(10)
                        .background(.white)
                        .overlay(alignment: .bottomTrailing) {
                            Text("MOSAIC  01").font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.58)).padding(15)
                        }
                        .rotationEffect(.degrees(-0.6))
                        .shadow(color: MosaicTheme.warmShadow, radius: 12, y: 6)
                        .opacity(hasDeveloped ? 1 : 0.18)
                        .saturation(hasDeveloped ? 1 : 0)
                        .blur(radius: hasDeveloped ? 0 : 8)
                        .accessibilityLabel("Developed \(look.title) photo preview")
                }
                Text("Keep this frame?").font(MosaicTheme.display(28, weight: .semibold))
                Text("Keeping uses one shot. Retaking does not.").foregroundStyle(MosaicTheme.muted)
                Button("Keep photo", action: keep)
                    .buttonStyle(MosaicPrimaryButtonStyle())
                    .accessibilityIdentifier("camera.review.keep")
                Button("Retake", action: retake)
                    .buttonStyle(MosaicSecondaryButtonStyle())
                    .accessibilityIdentifier("camera.review.retake")
            }.padding(20)
        }
        .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.7), value: hasDeveloped)
        .task {
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(180)) }
            hasDeveloped = true
        }
    }
}

private struct FilmDevelopmentOverlay: View {
    let look: FilmLookID
    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            MosaicTheme.ink.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 16) {
                FilmCanister(frameCount: 1)
                    .scaleEffect(1.2)
                ProgressView().tint(MosaicTheme.gold)
                Text("Developing \(look.title)…")
                    .font(MosaicTheme.display(24, weight: .semibold))
                Text("The fixed film look is being applied on this device.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MosaicTheme.porcelain.opacity(0.72))
            }
            .foregroundStyle(MosaicTheme.porcelain)
            .padding(24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Developing \(look.title) photo on this device")
        .accessibilityAddTraits([.isModal, .updatesFrequently])
        .accessibilityFocused($isFocused)
        .accessibilityIdentifier("camera.developing")
        .onAppear { isFocused = true }
    }
}

private struct SealedRollView: View {
    let photos: [EventPhoto]
    let delete: (EventPhoto) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                FilmCanister(frameCount: photos.count)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your sealed roll")
                        .font(MosaicTheme.display(24, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("\(photos.count) kept · develops at reveal")
                        .font(.caption)
                        .foregroundStyle(MosaicTheme.muted)
                }
            }
            Text("Only you can see these before reveal.").font(.footnote).foregroundStyle(MosaicTheme.muted)
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        VStack(spacing: 6) {
                            PhotoThumbnail(photo: photo).frame(width: 104, height: 134)
                                .padding(6).padding(.bottom, 14).background(.white)
                                .overlay(alignment: .bottomLeading) {
                                    Text("FRAME \(String(format: "%02d", index + 1))")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.black.opacity(0.58)).padding(7)
                                }
                                .rotationEffect(.degrees(index.isMultiple(of: 2) ? -0.8 : 0.8))
                                .shadow(color: MosaicTheme.warmShadow, radius: 5, y: 3)
                            Button("Delete", role: .destructive) { delete(photo) }.font(.caption).frame(minHeight: 44)
                        }
                    }
                }
            }.scrollIndicators(.hidden)
        }
    }
}

struct FilmCanister: View {
    let frameCount: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(MosaicTheme.ink)
                .frame(width: 48, height: 56)
            Rectangle()
                .fill(MosaicTheme.gold)
                .frame(width: 48, height: 18)
            VStack(spacing: 1) {
                Text("M")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                Text(String(format: "%02d", frameCount))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(MosaicTheme.ink)
        }
        .overlay(alignment: .top) {
            Capsule().fill(MosaicTheme.muted).frame(width: 24, height: 5).offset(y: -3)
        }
        .shadow(color: MosaicTheme.warmShadow, radius: 4, y: 3)
        .accessibilityHidden(true)
    }
}

struct DisposableCameraShell<Preview: View>: View {
    let event: MosaicSummary
    let shotsRemaining: Int
    let preview: Preview
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(event: MosaicSummary, shotsRemaining: Int, @ViewBuilder preview: () -> Preview) {
        self.event = event
        self.shotsRemaining = shotsRemaining
        self.preview = preview()
    }

    var body: some View {
        VStack(spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(event.filmLookID.title) film")
                        .font(.headline)
                    Label("\(shotsRemaining) shots remaining", systemImage: "camera.shutter.button")
                        .font(.body.bold())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(MosaicTheme.ink)
                .accessibilityIdentifier("camera.accessibilityFilmHeader")
            } else {
                hardwareHeader
                HStack {
                    FilmAdvanceWheel()
                    Spacer()
                    Text("ONE LOOK · ONE ROLL")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(MosaicTheme.ink.opacity(0.68))
                }
            }
            preview
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(.black.opacity(0.58), lineWidth: 5) }
            if !dynamicTypeSize.isAccessibilitySize {
                HStack {
                    Label("Fixed film", systemImage: "camera.filters")
                    Spacer()
                    Text("PHOTO ONLY")
                }
                .font(.caption2.bold())
                .tracking(0.8)
                .foregroundStyle(MosaicTheme.ink.opacity(0.72))
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [MosaicTheme.gold.opacity(0.92), MosaicTheme.clay.opacity(0.88)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.5), lineWidth: 1) }
        .shadow(color: MosaicTheme.warmShadow, radius: 10, y: 7)
        .frame(maxWidth: .infinity)
    }

    private var hardwareHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MOSAIC DISPOSABLE").font(.caption2.bold()).tracking(1.5)
                Text(event.filmLookID.title).font(MosaicTheme.display(20, weight: .semibold))
            }
            Spacer()
            CameraFlashWindow()
            VStack(spacing: 2) {
                Text("EXPOSURES").font(.system(size: 8, weight: .bold, design: .monospaced))
                Text("\(shotsRemaining)").font(.system(.title3, design: .monospaced, weight: .bold))
            }
            .foregroundStyle(MosaicTheme.porcelain)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(MosaicTheme.ink, in: RoundedRectangle(cornerRadius: 7))
        }
    }
}

private struct CameraFlashWindow: View {
    var body: some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [.white, MosaicTheme.sky.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 34, height: 22)
                .overlay { RoundedRectangle(cornerRadius: 3).stroke(MosaicTheme.ink.opacity(0.55), lineWidth: 2) }
            Text("FLASH")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(MosaicTheme.ink.opacity(0.7))
        .accessibilityHidden(true)
    }
}

private struct FilmAdvanceWheel: View {
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(MosaicTheme.ink.opacity(0.82)).frame(width: 26, height: 26)
                ForEach(0..<8, id: \.self) { index in
                    Capsule()
                        .fill(MosaicTheme.porcelain.opacity(0.72))
                        .frame(width: 2, height: 7)
                        .offset(y: -8)
                        .rotationEffect(.degrees(Double(index) * 45))
                }
            }
            Text("ADVANCE")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(MosaicTheme.ink.opacity(0.7))
        .accessibilityHidden(true)
    }
}

struct CameraShutter: View {
    var body: some View {
        ZStack {
            Circle().fill(MosaicTheme.ink).frame(width: 88, height: 88).shadow(color: MosaicTheme.warmShadow, radius: 6, y: 4)
            Circle().stroke(MosaicTheme.porcelain, lineWidth: 2).frame(width: 70, height: 70)
            Circle().fill(MosaicTheme.porcelain).frame(width: 56, height: 56)
        }
        .contentShape(Circle())
    }
}
