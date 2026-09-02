import AVFoundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

struct EvidenceCameraView: View {
    let contextTitle: String
    let privacyCopy: String
    let filmLookID: FilmLookID
    let dismissOnUse: Bool
    let onUsePhoto: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var camera = MosaicCameraController()
    @State private var libraryItem: PhotosPickerItem?
    @State private var capturedData: Data?
    @State private var flashOverlay = false
    @State private var isDeveloping = false

    init(mission: Mission, onUsePhoto: @escaping (Data) -> Void) {
        self.contextTitle = mission.title
        self.privacyCopy = "Evidence stays private"
        self.filmLookID = .sunwashed
        self.dismissOnUse = true
        self.onUsePhoto = onUsePhoto
    }

    init(challenge: KindnessChallenge, dismissOnUse: Bool = false, onUsePhoto: @escaping (Data) -> Void) {
        self.contextTitle = challenge.name
        self.privacyCopy = "Private until you seal it"
        self.filmLookID = challenge.filmLookID
        self.dismissOnUse = dismissOnUse
        self.onUsePhoto = onUsePhoto
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let capturedData, let image = UIImage(data: capturedData) {
                review(image, data: capturedData)
            } else {
                livePreview
            }
            if flashOverlay { Color.white.ignoresSafeArea().allowsHitTesting(false) }
        }
        .task { await camera.prepare() }
        .onDisappear { camera.stop() }
        .task(id: libraryItem) { await loadLibraryPhoto() }
        .onChange(of: camera.photoData) { _, data in
            guard let data else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeOut(duration: 0.08)) { flashOverlay = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                flashOverlay = false
                await develop(data)
            }
        }
    }

    private var livePreview: some View {
        GeometryReader { _ in
            ZStack {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.62), location: 0),
                        .init(color: .clear, location: 0.3),
                        .init(color: .clear, location: 0.6),
                        .init(color: .black.opacity(0.76), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                MosaicTheme.porcelain
                    .frame(height: 80)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)

                VStack(spacing: 12) {
                    cameraHeader

                    Label(privacyCopy, systemImage: "lock.shield.fill")
                        .font(MosaicTheme.caption(.bold))
                        .foregroundStyle(MosaicTheme.indigo)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(MosaicTheme.paper.opacity(0.96), in: Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                    if camera.permissionDenied {
                        Spacer()
                        cameraPermissionRationale
                        Spacer()
                    } else {
                        Spacer()
                    }

                    Label("Avoid faces, addresses, and private details", systemImage: "hand.raised.fill")
                        .font(MosaicTheme.caption(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.54), in: Capsule())

                    if isDeveloping {
                        Label("Developing \(filmLookID.title)…", systemImage: "sparkles")
                            .font(MosaicTheme.caption(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.62), in: Capsule())
                    }

                    captureDeck
                        .padding(.horizontal, -20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
        }
    }

    private var cameraHeader: some View {
        HStack(spacing: 12) {
            ceramicControl("xmark", label: "Close camera") { dismiss() }
            Spacer(minLength: 0)
            Label(contextTitle, systemImage: "camera.aperture")
                .font(MosaicTheme.body(.semibold))
                .foregroundStyle(MosaicTheme.indigo)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(MosaicTheme.paper.opacity(0.96), in: Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            Spacer(minLength: 0)
            ceramicControl(
                camera.flashEnabled ? "bolt.fill" : "bolt.slash.fill",
                label: camera.flashEnabled ? "Turn flash off" : "Turn flash on",
                selected: camera.flashEnabled
            ) { camera.toggleFlash() }
        }
    }

    private var cameraPermissionRationale: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MosaicTheme.indigo)
            Text("Let Mosaic use the camera")
                .font(MosaicTheme.display(24, weight: .semibold))
            Text("Capture a private moment for this Mosaic, or choose one you already have.")
                .font(MosaicTheme.caption())
                .foregroundStyle(MosaicTheme.muted)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .foregroundStyle(MosaicTheme.ink)
        .padding(20)
        .frame(maxWidth: 320)
        .background(MosaicTheme.paper.opacity(0.98), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
    }

    private var captureDeck: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(MosaicTheme.ink)
                        .frame(width: 52, height: 52)
                        .background(MosaicTheme.raisedPaper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel("Choose from library")

                Button { camera.capture() } label: {
                    ZStack {
                        Circle().fill(MosaicTheme.paper)
                        Circle().stroke(MosaicTheme.indigo, lineWidth: 4).padding(9)
                    }
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 7)
                    .opacity(camera.isReady ? 1 : 0.48)
                }
                .disabled(!camera.isReady)
                .accessibilityLabel(camera.isReady ? "Take photo" : "Camera is preparing")

                Button { camera.flip() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(MosaicTheme.ink)
                        .frame(width: 52, height: 52)
                        .background(MosaicTheme.raisedPaper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel("Flip camera")
            }

            HStack(spacing: 6) {
                Circle().fill(MosaicTheme.indigo).frame(width: 6, height: 6)
                Text("PHOTO  ·  PRIVATE EVIDENCE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(MosaicTheme.muted)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(MosaicTheme.porcelain.opacity(0.98))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func review(_ image: UIImage, data: Data) -> some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()

                LinearGradient(colors: [.black.opacity(0.5), .clear, .black.opacity(0.36)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                MosaicTheme.porcelain
                    .frame(height: 80)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack {
                        ceramicControl("xmark", label: "Close review") { dismiss() }
                        Spacer()
                        Text("REVIEW MOMENT")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                        Spacer()
                        Color.clear.frame(width: 52, height: 52)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()

                    VStack(spacing: 16) {
                        Capsule()
                            .fill(MosaicTheme.muted.opacity(0.34))
                            .frame(width: 40, height: 4)
                        VStack(spacing: 4) {
                            Text("Keep this moment?")
                                .font(MosaicTheme.display(26, weight: .semibold))
                            Label("\(filmLookID.title) disposable film", systemImage: "camera.aperture")
                                .font(MosaicTheme.caption(.semibold))
                                .foregroundStyle(MosaicTheme.persimmon)
                            Label(privacyCopy, systemImage: "lock.fill")
                                .font(MosaicTheme.caption(.semibold))
                                .foregroundStyle(MosaicTheme.indigo)
                        }

                        HStack(spacing: 12) {
                            Button {
                                capturedData = nil
                                camera.photoData = nil
                            } label: {
                                Text("Retake")
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button {
                                onUsePhoto(data)
                                if dismissOnUse { dismiss() }
                            } label: {
                                Label("Use Photo", systemImage: "checkmark")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    .foregroundStyle(MosaicTheme.ink)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .background {
                        UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                            .fill(MosaicTheme.porcelain.opacity(0.98))
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
            }
        }
    }

    private func ceramicControl(
        _ symbol: String,
        label: String,
        selected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(selected ? Color.white : MosaicTheme.ink)
                .frame(width: 52, height: 52)
                .background(selected ? MosaicTheme.indigo : MosaicTheme.paper.opacity(0.96), in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .accessibilityLabel(label)
    }

    private func loadLibraryPhoto() async {
        guard let data = try? await libraryItem?.loadTransferable(type: Data.self) else { return }
        await develop(data)
    }

    private func develop(_ data: Data) async {
        isDeveloping = true
        let look = filmLookID
        let developed = await Task.detached(priority: .userInitiated) {
            DisposableCameraFilter.developJPEG(data, look: look)
        }.value
        capturedData = developed ?? data
        isDeveloping = false
    }
}

@MainActor
@Observable
final class MosaicCameraController: NSObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    var isReady = false
    var permissionDenied = false
    var flashEnabled = false
    var photoData: Data?
    private let output = AVCapturePhotoOutput()
    private var position: AVCaptureDevice.Position = .back

    func prepare() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            permissionDenied = true
            return
        }
        permissionDenied = false
        configure()
        session.startRunning()
        isReady = true
    }

    func stop() { if session.isRunning { session.stopRunning() } }
    func toggleFlash() { flashEnabled.toggle() }

    func flip() {
        position = position == .back ? .front : .back
        session.stopRunning()
        configure()
        session.startRunning()
    }

    func capture() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashEnabled && position == .back ? .on : .off
        output.capturePhoto(with: settings, delegate: self)
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.inputs.forEach(session.removeInput)
        if !session.outputs.contains(output), session.canAddOutput(output) { session.addOutput(output) }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in self.photoData = data }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) { uiView.previewLayer.session = session }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
