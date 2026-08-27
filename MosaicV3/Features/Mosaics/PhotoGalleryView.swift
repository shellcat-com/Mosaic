import SwiftUI

struct PhotoGalleryView: View {
    let event: MosaicEvent
    @Binding var path: [MosaicRoute]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if dynamicTypeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 10) { galleryHeading; recapButton } }
            else { HStack { galleryHeading; Spacer(); recapButton } }
            if event.photos.isEmpty {
                ContentUnavailableView("No photos", systemImage: "photo.on.rectangle.angled", description: Text("No eligible photos were captured before reveal."))
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(event.photos) { photo in
                        Button { path.append(.photo(photo.id)) } label: {
                            PhotoThumbnail(photo: photo).aspectRatio(0.78, contentMode: .fit)
                                .padding(5).padding(.bottom, 10).background(.white)
                                .shadow(color: MosaicTheme.warmShadow, radius: 3, y: 2)
                        }.buttonStyle(.plain).accessibilityLabel("Photo by \(photo.photographerDisplayName)")
                    }
                }
            }
        }
    }

    private var galleryHeading: some View {
                VStack(alignment: .leading) {
                    Text("Disposable gallery").font(MosaicTheme.display(27, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("\(event.photos.count) developed photos").font(.subheadline).foregroundStyle(MosaicTheme.muted)
                }
    }

    private var recapButton: some View {
        Button("Make recap") { path.append(.recap(event.id)) }.disabled(event.photos.isEmpty)
    }
}

struct PhotoThumbnail: View {
    let photo: EventPhoto
    var body: some View {
        Group {
            if let url = photo.displayURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Rectangle().fill(MosaicTheme.claySurface).overlay { ProgressView() } }
                }
            } else {
                Rectangle().fill(MosaicTheme.claySurface).overlay { Image(systemName: "photo").foregroundStyle(MosaicTheme.muted) }
            }
        }.clipped().clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct EventPhotoDetailView: View {
    @Environment(MosaicAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let photoID: UUID
    @State private var message: String?

    private var photo: EventPhoto? { model.detail.event?.photos.first { $0.id == photoID } }

    var body: some View {
        MosaicPage {
            if let photo {
                VStack(alignment: .leading, spacing: 18) {
                    PhotoThumbnail(photo: photo).aspectRatio(CGFloat(photo.pixelWidth) / CGFloat(max(1, photo.pixelHeight)), contentMode: .fit)
                    Label(photo.photographerDisplayName, systemImage: "person.crop.circle")
                    Label(photo.capturedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    if photo.isMine {
                        Button("Delete photo", role: .destructive) { Task { await delete(photo) } }.buttonStyle(MosaicSecondaryButtonStyle())
                    } else {
                        Button("Report photo", systemImage: "exclamationmark.bubble", role: .destructive) { Task { await report(photo) } }.buttonStyle(MosaicSecondaryButtonStyle())
                        Button("Block \(photo.photographerDisplayName)", role: .destructive) { Task { await block(photo) } }.buttonStyle(MosaicSecondaryButtonStyle())
                    }
                    if let message { Text(message).font(.footnote).foregroundStyle(.red) }
                }
            }
        }
        .navigationTitle("Photo")
        .mosaicAccessibilityAnnouncement(message)
    }

    private func delete(_ photo: EventPhoto) async {
        do { try await model.detail.deletePhoto(photo.id); dismiss() } catch { message = error.localizedDescription }
    }
    private func report(_ photo: EventPhoto) async {
        do { try await model.detail.reportPhoto(photo.id, reason: "Inappropriate shared photo"); dismiss() } catch { message = error.localizedDescription }
    }
    private func block(_ photo: EventPhoto) async {
        do { try await model.detail.block(photo.photographerID); dismiss() } catch { message = error.localizedDescription }
    }
}
