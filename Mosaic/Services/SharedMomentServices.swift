import Foundation
import Network
import UIKit
import UserNotifications

enum NetworkConnectivity {
    static func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in continuation.yield(path.status == .satisfied) }
            monitor.start(queue: DispatchQueue(label: "com.mosaic.shared-roll-connectivity"))
            continuation.onTermination = { _ in monitor.cancel() }
        }
    }
}

actor ProtectedSharedMomentStore: SharedMomentMediaStore {
    static let shared = ProtectedSharedMomentStore()

    private var directory: URL {
        get throws {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let url = base.appendingPathComponent("SharedMomentDrafts", isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutable = url
            try mutable.setResourceValues(values)
            return url
        }
    }

    nonisolated static func localURL(for name: String?) -> URL? {
        guard let name,
              let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let url = base.appendingPathComponent("SharedMomentDrafts", isDirectory: true).appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func storeDraft(_ jpegData: Data, id: UUID) async throws -> String {
        guard let source = UIImage(data: jpegData),
              let normalized = source.sharedMomentNormalized(maxDimension: 2_400),
              let output = normalized.jpegData(compressionQuality: 0.88) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let name = "\(id.uuidString.lowercased()).jpg"
        try output.write(
            to: try directory.appendingPathComponent(name),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
        if let thumbnail = source.sharedMomentNormalized(maxDimension: 256)?.jpegData(compressionQuality: 0.72) {
            try thumbnail.write(
                to: try directory.appendingPathComponent("\(id.uuidString.lowercased())-analysis.jpg"),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        }
        return name
    }

    func data(for localAssetName: String) async throws -> Data {
        try Data(contentsOf: try directory.appendingPathComponent(localAssetName))
    }

    func remove(localAssetName: String) async {
        try? FileManager.default.removeItem(at: try directory.appendingPathComponent(localAssetName))
        let analysisName = localAssetName.replacingOccurrences(of: ".jpg", with: "-analysis.jpg")
        try? FileManager.default.removeItem(at: try directory.appendingPathComponent(analysisName))
    }
}

actor LocalSharedMomentRepository: SharedMomentRepository {
    private let mediaStore: SharedMomentMediaStore
    private var items: [UUID: SharedMoment] = [:]
    private var didLoad = false

    init(mediaStore: SharedMomentMediaStore = ProtectedSharedMomentStore.shared) {
        self.mediaStore = mediaStore
    }

    func moments(challengeID: UUID) async throws -> [SharedMoment] {
        loadIfNeeded()
        return items.values.filter { $0.challengeID == challengeID && $0.lifecycle != .deleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func saveDraft(_ moment: SharedMoment, jpegData: Data) async throws -> SharedMoment {
        loadIfNeeded()
        var draft = moment
        draft.localAssetName = try await mediaStore.storeDraft(jpegData, id: draft.id)
        if draft.lifecycle != .uploadPending { draft.lifecycle = .localDraft }
        items[draft.id] = draft
        persist()
        return draft
    }

    func seal(_ moment: SharedMoment, jpegData: Data) async throws -> SharedMoment {
        loadIfNeeded()
        var saved = moment
        if saved.localAssetName == nil {
            saved.localAssetName = try await mediaStore.storeDraft(jpegData, id: saved.id)
        }
        saved.lifecycle = .approved // Local fallback has no organizer service; preserve the production contract in Supabase.
        saved.updatedAt = .now
        items[saved.id] = saved
        persist()
        return saved
    }

    func updateConsent(momentID: UUID, reveal: Bool, export: Bool) async throws -> SharedMoment {
        loadIfNeeded()
        guard var item = items[momentID] else { throw CocoaError(.fileNoSuchFile) }
        item.revealConsent = reveal
        item.exportConsent = export
        item.consentVersion += 1
        item.lifecycle = reveal ? item.lifecycle : .consentRevoked
        item.updatedAt = .now
        items[momentID] = item
        persist()
        return item
    }

    func moderate(momentID: UUID, approved: Bool) async throws -> SharedMoment {
        loadIfNeeded()
        guard var item = items[momentID] else { throw CocoaError(.fileNoSuchFile) }
        item.lifecycle = approved ? .approved : .rejected
        item.updatedAt = .now
        items[momentID] = item
        persist()
        return item
    }

    func delete(momentID: UUID) async throws {
        loadIfNeeded()
        guard var item = items[momentID] else { return }
        item.lifecycle = .deleted
        item.updatedAt = .now
        items[momentID] = item
        persist()
        if let name = item.localAssetName { await mediaStore.remove(localAssetName: name) }
    }

    private var metadataURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let directory = base.appendingPathComponent("SharedMomentDrafts", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("moments.json")
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let metadataURL, let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([SharedMoment].self, from: data) else { return }
        items = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persist() {
        guard let metadataURL, let data = try? JSONEncoder().encode(Array(items.values)) else { return }
        try? data.write(to: metadataURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

actor LocalMomentReminderService: MomentReminderService {
    static let shared = LocalMomentReminderService()

    func requestAndSchedule(for challenge: ChallengeSummary, lastActivity: Date?) async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else { return false }
            await cancel(challengeID: challenge.id)
            for request in Self.requests(for: challenge, lastActivity: lastActivity) {
                try await center.add(request)
            }
            return true
        } catch {
            return false
        }
    }

    func cancel(challengeID: UUID) async {
        let prefix = "mosaic.roll.\(challengeID.uuidString.lowercased())."
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
    }

    static func requests(for challenge: ChallengeSummary, lastActivity: Date?, now: Date = .now) -> [UNNotificationRequest] {
        guard challenge.revealAt > now else { return [] }
        let prefix = "mosaic.roll.\(challenge.id.uuidString.lowercased())."
        var result: [UNNotificationRequest] = []
        let dayBefore = challenge.revealAt.addingTimeInterval(-86_400)
        if dayBefore > now, lastActivity.map({ $0 < dayBefore }) ?? true {
            let content = UNMutableNotificationContent()
            content.title = "One more moment, if it feels right"
            content.body = "Your shared roll for \(challenge.name) reveals tomorrow."
            content.sound = .default
            content.userInfo = ["url": "mosaic://camera/\(challenge.id.uuidString.lowercased())"]
            result.append(UNNotificationRequest(identifier: prefix + "last", content: content,
                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: dayBefore.timeIntervalSince(now), repeats: false)))
        }
        let reveal = UNMutableNotificationContent()
        reveal.title = "Your shared roll is ready"
        reveal.body = "Open \(challenge.name) and watch your moments become a mosaic."
        reveal.sound = .default
        reveal.userInfo = ["url": "mosaic://recap/\(challenge.id.uuidString.lowercased())"]
        result.append(UNNotificationRequest(identifier: prefix + "reveal", content: reveal,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: challenge.revealAt.timeIntervalSince(now), repeats: false)))
        return Array(result.prefix(2))
    }
}

private extension UIImage {
    func sharedMomentNormalized(maxDimension: CGFloat) -> UIImage? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: target))
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
