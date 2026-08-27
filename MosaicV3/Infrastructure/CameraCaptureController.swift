@preconcurrency import AVFoundation
import Observation
import SwiftUI
import UIKit

enum CameraCaptureError: LocalizedError {
    case permissionDenied
    case cameraUnavailable
    case configurationFailed
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Camera access is off. Enable it in Settings to take photos."
        case .cameraUnavailable: "No camera is available on this device."
        case .configurationFailed: "Mosaic could not start the camera."
        case .captureFailed: "That frame did not develop. Please try again."
        }
    }
}

@MainActor @Observable
final class CameraCaptureController: NSObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<Data, any Error>?
    private(set) var permissionDenied = false
    private(set) var isReady = false

    func start() async throws {
        let authorized: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true
        case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
        default: authorized = false
        }
        guard authorized else {
            permissionDenied = true
            throw CameraCaptureError.permissionDenied
        }
        permissionDenied = false
        if !isReady { try configure() }
        if !session.isRunning { session.startRunning() }
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
    }

    func capture() async throws -> Data {
        guard isReady, continuation == nil else { throw CameraCaptureError.captureFailed }
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            guard let continuation = self.continuation else { return }
            self.continuation = nil
            if let error { continuation.resume(throwing: error) }
            else if let data { continuation.resume(returning: data) }
            else { continuation.resume(throwing: CameraCaptureError.captureFailed) }
        }
    }

    private func configure() throws {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraCaptureError.cameraUnavailable
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input), session.canAddOutput(output) else { throw CameraCaptureError.configurationFailed }
        session.addInput(input)
        session.addOutput(output)
        isReady = true
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer?.session = session
        view.previewLayer?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer?.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
    }
}
