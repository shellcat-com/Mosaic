import AVFoundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

struct EvidenceCameraView: View {
    let contextTitle: String
    let privacyCopy: String
    let dismissOnUse: Bool
    let onUsePhoto: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var camera = MosaicCameraController()
    @State private var libraryItem: PhotosPickerItem?
    @State private var capturedData: Data?
    @State private var flashOverlay = false

    init(mission: Mission, onUsePhoto: @escaping (Data) -> Void) {
        self.contextTitle = mission.title
        self.privacyCopy = "Evidence stays private"
        self.dismissOnUse = true
        self.onUsePhoto = onUsePhoto
    }

    init(challenge: KindnessChallenge, dismissOnUse: Bool = false, onUsePhoto: @escaping (Data) -> Void) {
        self.contextTitle = challenge.name
        self.privacyCopy = "Private until you seal it"
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
            if flashOverlay { MosaicTheme.persimmon.opacity(0.72).ignoresSafeArea().allowsHitTesting(false) }
        }
        .task { await camera.prepare() }
        .onDisappear { camera.stop() }
        .task(id: libraryItem) {
            if let data = try? await libraryItem?.loadTransferable(type: Data.self) { capturedData = data }
        }
        .onChange(of: camera.photoData) { _, data in
            guard let data else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeOut(duration: 0.08)) { flashOverlay = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                flashOverlay = false
                capturedData = data
            }
        }
    }

    private var livePreview: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.62), .clear, .black.opacity(0.76)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea().allowsHitTesting(false)
            Canvas { context, size in
                for index in 0..<70 {
                    let x = CGFloat((index * 47) % 101) / 101 * size.width
                    let y = CGFloat((index * 71) % 103) / 103 * size.height
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(0.12)))
                }
            }
            .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)

            VStack(spacing: 13) {
                HStack {
                    ceramicIcon("xmark", label: "Close") { dismiss() }
                    Spacer()
                    Label(contextTitle, systemImage: "camera.aperture")
                        .font(.subheadline.weight(.bold)).foregroundStyle(MosaicTheme.indigo)
                        .lineLimit(1).padding(.horizontal, 15).padding(.vertical, 11)
                        .background(MosaicTheme.paper, in: Capsule())
                    Spacer()
                    ceramicIcon(camera.flashEnabled ? "bolt.fill" : "bolt.slash.fill", label: "Flash") { camera.toggleFlash() }
                }
                Label(privacyCopy, systemImage: "shield.lefthalf.filled")
                    .font(.caption.weight(.bold)).foregroundStyle(MosaicTheme.indigo)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(MosaicTheme.paper.opacity(0.95), in: Capsule())
                if camera.permissionDenied {
                    VStack(spacing: 7) {
                        Text("Camera access is off").font(.headline)
                        Text("You can choose a photo below or enable Camera in Settings.")
                            .font(.caption).multilineTextAlignment(.center)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(MosaicTheme.ink)
                    .padding(14)
                    .background(MosaicTheme.paper.opacity(0.96), in: RoundedRectangle(cornerRadius: 18))
                }
                Spacer()
                Label("Choose what belongs in the group reveal", systemImage: "hand.raised.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(.black.opacity(0.58), in: Capsule())
                HStack(spacing: 34) {
                    PhotosPicker(selection: $libraryItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2.weight(.semibold)).foregroundStyle(MosaicTheme.ink)
                            .frame(width: 52, height: 52).background(MosaicTheme.paper, in: Circle())
                    }
                    .accessibilityLabel("Choose from library")

                    Button { camera.capture() } label: {
                        Circle().fill(MosaicTheme.paper).frame(width: 94, height: 94)
                            .overlay(Circle().stroke(MosaicTheme.indigo, lineWidth: 5).padding(10))
                            .overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 1).padding(3))
                            .shadow(color: .black.opacity(0.38), radius: 16, y: 9)
                    }
                    .disabled(!camera.isReady).accessibilityLabel("Take photo")

                    ceramicIcon("arrow.triangle.2.circlepath.camera", label: "Flip camera") { camera.flip() }
                }
                .padding(.bottom, 22)
            }
            .padding(.horizontal, 20).padding(.top, 10)
        }
    }

    private func review(_ image: UIImage, data: Data) -> some View {
        VStack(spacing: 0) {
            Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            VStack(spacing: 16) {
                Capsule().fill(MosaicTheme.muted.opacity(0.32)).frame(width: 42, height: 5)
                Label("A moment worth keeping", systemImage: "sparkles")
                    .font(MosaicTheme.display(23, weight: .semibold))
                HStack(spacing: 12) {
                    Button("Retake") { capturedData = nil; camera.photoData = nil }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Use Photo") {
                        onUsePhoto(data)
                        if dismissOnUse { dismiss() }
                    }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(20).background(MosaicTheme.paper)
        }
    }

    private func ceramicIcon(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.headline).foregroundStyle(MosaicTheme.ink)
                .frame(width: 50, height: 50).background(MosaicTheme.paper.opacity(0.96), in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .accessibilityLabel(label)
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
