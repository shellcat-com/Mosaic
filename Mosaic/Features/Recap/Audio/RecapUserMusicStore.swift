import Foundation

/// Personal music import is deliberately deferred until the bundled catalog ships safely.
/// Keeping the boundary explicit prevents personal audio from being uploaded accidentally.
actor RecapUserMusicStore {
    static let shared = RecapUserMusicStore()

    let isImportAvailable = false

    func tracks() -> [RecapMusicTrack] { [] }
}
