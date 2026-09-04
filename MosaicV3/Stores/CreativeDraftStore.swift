import Foundation

struct MosaicCreationWorkspace: Hashable, Sendable {
    var draft: MosaicDraft
    var step: Int
    var selectedPresetID: String?
}

@MainActor
final class CreativeDraftStore {
    private(set) var creation: MosaicCreationWorkspace?
    private var recapProjects: [UUID: PhotoRecapProject] = [:]
    private var recapStages: [UUID: String] = [:]

    func saveCreation(draft: MosaicDraft, step: Int, selectedPresetID: String?) {
        creation = .init(draft: draft, step: step, selectedPresetID: selectedPresetID)
    }

    func clearCreation() {
        creation = nil
    }

    func recapProject(for mosaicID: UUID) -> PhotoRecapProject? {
        recapProjects[mosaicID]
    }

    func recapStage(for mosaicID: UUID) -> String? {
        recapStages[mosaicID]
    }

    func saveRecap(_ project: PhotoRecapProject, stage: String) {
        if project.hasEdits {
            recapProjects[project.mosaicID] = project
            recapStages[project.mosaicID] = stage
        } else {
            clearRecap(for: project.mosaicID)
        }
    }

    func clearRecap(for mosaicID: UUID) {
        recapProjects[mosaicID] = nil
        recapStages[mosaicID] = nil
    }

    func clearPrivateState() {
        creation = nil
        recapProjects.removeAll()
        recapStages.removeAll()
    }
}
