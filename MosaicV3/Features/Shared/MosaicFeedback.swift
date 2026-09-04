import SwiftUI

enum MosaicFeedbackKind: Equatable {
    case success
    case error
    case information

    var symbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .information: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: MosaicTheme.accentForeground
        case .error: .red
        case .information: MosaicTheme.accentForeground
        }
    }
}

struct MosaicFeedback: Equatable {
    let message: String
    let kind: MosaicFeedbackKind
}

struct MosaicFeedbackView: View {
    let feedback: MosaicFeedback

    var body: some View {
        Label(feedback.message, systemImage: feedback.kind.symbol)
            .font(.footnote)
            .foregroundStyle(feedback.kind.color)
            .accessibilityLabel("\(accessibilityPrefix): \(feedback.message)")
    }

    private var accessibilityPrefix: String {
        switch feedback.kind {
        case .success: "Success"
        case .error: "Error"
        case .information: "Information"
        }
    }
}
