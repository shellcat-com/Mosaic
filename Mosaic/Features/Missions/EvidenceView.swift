import AVFoundation
import PhotosUI
import SwiftUI

struct EvidenceView: View {
    let mission: Mission
    @State private var method: EvidenceMethod
    @State private var reflection = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var videoDuration: Double?
    @State private var mediaError: String?
    @State private var partnerName = ""
    @State private var proceed = false
    @State private var showingMediaPicker = false
    @State private var showingMosaicCamera = false
    @State private var pickerSource: UIImagePickerController.SourceType = .camera
    @State private var pendingCameraPhoto: Data?

    init(mission: Mission) {
        self.mission = mission
        _method = State(initialValue: mission.evidence.first ?? .reflection)
    }

    private var canContinue: Bool {
        switch method {
        case .reflection: !reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .photo, .receipt: photoData != nil
        case .video: photoData != nil && (videoDuration ?? 11) <= 10
        case .partner: false
        case .organizer: true
        }
    }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                MosaicProgressRail(current: 2, total: 5)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Verify privately")
                        .font(MosaicTheme.display(36, weight: .semibold))
                    Text(mission.title)
                        .foregroundStyle(MosaicTheme.muted)
                }

                Label("Evidence stays private", systemImage: "lock.shield.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MosaicTheme.indigo)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(MosaicTheme.indigo.opacity(0.09), in: Capsule())

                OrganicPanel(variant: .leaningLeft, tint: MosaicTheme.indigo.opacity(0.08)) {
                    Picker("Evidence method", selection: $method) {
                        ForEach(mission.evidence) { evidence in
                            Label(evidence.title, systemImage: evidence.symbol).tag(evidence)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                OrganicPanel(variant: .leaningRight) {
                    evidenceInput
                }

                Label("Avoid faces, addresses, school identifiers, payment details, and other private information.", systemImage: "shield.lefthalf.filled")
                    .font(.footnote)
                    .foregroundStyle(MosaicTheme.muted)
                    .porcelainCard()
            }
        }
        .navigationTitle("Evidence")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Review privacy") { proceed = true }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.45)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
        }
        .navigationDestination(isPresented: $proceed) {
            PrivacyReviewView(
                mission: mission,
                method: method,
                reflection: reflection,
                photoData: photoData,
                videoDuration: videoDuration
            )
        }
        .sheet(isPresented: $showingMediaPicker) {
            PrivateMediaPicker(sourceType: pickerSource, method: method) { data, duration in
                photoData = data
                videoDuration = duration
                mediaError = nil
            } onError: { message in
                photoData = nil
                videoDuration = nil
                mediaError = message
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingMosaicCamera, onDismiss: finishCameraCapture) {
            EvidenceCameraView(mission: mission) { data in
                pendingCameraPhoto = UIImage(data: data)?.jpegData(compressionQuality: 0.88)
            }
        }
        .task(id: selectedPhoto) {
            guard let selectedPhoto else {
                photoData = nil
                videoDuration = nil
                return
            }
            do {
                guard let loaded = try await selectedPhoto.loadTransferable(type: Data.self) else { return }
                if method == .video {
                    let temporaryURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("mosaic-\(UUID().uuidString).mov")
                    try loaded.write(to: temporaryURL, options: .atomic)
                    let duration = try await AVURLAsset(url: temporaryURL).load(.duration).seconds
                    try? FileManager.default.removeItem(at: temporaryURL)
                    try EvidenceUploadPolicy.validate(method: .video, byteCount: loaded.count, duration: duration)
                    photoData = loaded
                    videoDuration = duration
                } else if let image = UIImage(data: loaded), let jpeg = image.jpegData(compressionQuality: 0.82) {
                    try EvidenceUploadPolicy.validate(method: method, byteCount: jpeg.count, duration: nil)
                    photoData = jpeg
                    videoDuration = nil
                } else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                mediaError = nil
            } catch {
                photoData = nil
                mediaError = error.localizedDescription
            }
        }
    }

    private func finishCameraCapture() {
        guard let pendingCameraPhoto else { return }
        photoData = pendingCameraPhoto
        self.pendingCameraPhoto = nil
        videoDuration = nil
        mediaError = nil
        proceed = true
    }

    @ViewBuilder
    private var evidenceInput: some View {
        switch method {
        case .reflection:
            VStack(alignment: .leading, spacing: 10) {
                Text("What did this moment mean to you?").font(.headline)
                TextEditor(text: $reflection)
                    .frame(minHeight: 170)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(MosaicTheme.raisedPaper, in: OrganicPanelShape(variant: .softRectangle))
                    .overlay { OrganicPanelShape(variant: .softRectangle).stroke(MosaicTheme.border, lineWidth: 1) }
                Text("A short, honest reflection is enough.").font(.caption).foregroundStyle(MosaicTheme.muted)
            }
        case .photo, .video, .receipt:
            VStack(spacing: 16) {
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay {
                            if method == .receipt {
                                GeometryReader { proxy in
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                                            let point = CGPoint(
                                                x: min(max(value.location.x / max(proxy.size.width, 1), 0), 1),
                                                y: min(max(value.location.y / max(proxy.size.height, 1), 0), 1)
                                            )
                                            if let redacted = ReceiptImageProcessor.redact(photoData, at: point) {
                                                self.photoData = redacted
                                            }
                                        })
                                }
                            }
                        }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(MosaicTheme.ink.opacity(0.88))
                        VStack(spacing: 12) {
                            Image(systemName: method.symbol).font(.system(size: 42))
                            Text(method == .video ? "Choose a short video" : "Choose a private \(method.title.lowercased())")
                        }
                        .foregroundStyle(.white)
                    }
                    .frame(height: 280)
                }
                if method == .receipt {
                    Button {
                        pickerSource = .photoLibrary
                        showingMediaPicker = true
                    } label: {
                        Label("Choose & crop receipt", systemImage: "crop")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(MosaicTheme.paper, in: Capsule())
                    }
                } else {
                    PhotosPicker(selection: $selectedPhoto, matching: method == .video ? .videos : .images) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(MosaicTheme.paper, in: Capsule())
                    }
                }
                if method == .photo {
                    Button { showingMosaicCamera = true } label: {
                        Label("Open Mosaic Camera", systemImage: "camera.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(MosaicTheme.indigo.opacity(0.12), in: Capsule())
                    }
                } else if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        pickerSource = .camera
                        showingMediaPicker = true
                    } label: {
                        Label(method == .video ? "Record with Camera" : "Take with Camera", systemImage: "camera")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(MosaicTheme.indigo.opacity(0.1), in: Capsule())
                    }
                }
                if method == .photo {
                    TextField("Add a short note (optional)", text: $reflection, axis: .vertical)
                        .lineLimit(3).padding(14)
                        .background(MosaicTheme.raisedPaper, in: OrganicPanelShape(variant: .softRectangle))
                        .overlay { OrganicPanelShape(variant: .softRectangle).stroke(MosaicTheme.border, lineWidth: 1) }
                }
                if let videoDuration, method == .video, photoData != nil {
                    Label(String(format: "Selected video · %.1f seconds", videoDuration), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(MosaicTheme.sage)
                }
                if let mediaError {
                    Label(mediaError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(MosaicTheme.persimmon)
                }
                if method == .receipt {
                    Label("Crop first, then tap the preview to cover payment, address, or account details.", systemImage: "pencil.and.outline")
                        .font(.caption).foregroundStyle(MosaicTheme.muted)
                }
            }
        case .partner:
            ContentUnavailableView("Partner confirmation is coming later", systemImage: "person.badge.clock", description: Text("This post-hackathon method is not part of the judged act flow. Choose another evidence method."))
                .frame(minHeight: 230)
        case .organizer:
            ContentUnavailableView("Organizer approval", systemImage: "checkmark.seal", description: Text("Your contribution will reserve an unfired clay position while it waits for review."))
                .frame(minHeight: 230)
        }
    }
}
