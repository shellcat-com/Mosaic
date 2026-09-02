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
    private let captureSession = CameraCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.mosaic.camera-session", qos: .userInitiated)
    private var continuation: CheckedContinuation<Data, any Error>?
    private(set) var permissionDenied = false
    private(set) var isReady = false

    var session: AVCaptureSession { captureSession.session }

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
        if !isReady {
            try await performSessionWork { [captureSession] in try captureSession.configure() }
            isReady = true
        }
        try await performSessionWork { [captureSession] in captureSession.start() }
    }

    func stop() {
        sessionQueue.async { [captureSession] in captureSession.stop() }
    }

    func capture() async throws -> Data {
        guard isReady, continuation == nil else { throw CameraCaptureError.captureFailed }
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            captureSession.output.capturePhoto(with: settings, delegate: self)
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

    private func performSessionWork(_ work: @escaping @Sendable () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    try work()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private final class CameraCaptureSession: @unchecked Sendable {
    let session = AVCaptureSession()
    let output = AVCapturePhotoOutput()
    private var configured = false

    func configure() throws {
        guard !configured else { return }
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
        configured = true
    }

    func start() {
        if !session.isRunning { session.startRunning() }
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
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
