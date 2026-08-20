import EventKit
import EventKitUI
import SwiftUI

struct CalendarEventSheet: UIViewControllerRepresentable {
    let summary: ChallengeSummary
    var onSaved: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator { action in
            if action == .saved { onSaved?() }
            dismiss()
        }
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = "Mosaic Reveal: \(summary.name)"
        event.startDate = summary.revealAt
        event.endDate = summary.revealAt.addingTimeInterval(15 * 60)
        event.timeZone = .current
        event.url = summary.deepLink
        event.notes = "The community mosaic is ready to reveal. Open Mosaic to experience it together."

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        private let onComplete: (EKEventEditViewAction) -> Void

        init(onComplete: @escaping (EKEventEditViewAction) -> Void) {
            self.onComplete = onComplete
        }

        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            onComplete(action)
        }
    }
}
