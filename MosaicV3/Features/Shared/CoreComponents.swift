import SwiftUI
import UIKit

struct MosaicPage<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .porcelainBackground()
    }
}

struct MosaicTitle: View {
    let eyebrow: String
    let title: String
    let detail: String?

    init(_ title: String, eyebrow: String, detail: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(MosaicTheme.caption(.semibold))
                .tracking(1.2)
                .foregroundStyle(MosaicTheme.accentForeground)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 1)
            Text(title)
                .font(MosaicTheme.display(30, weight: .semibold))
                .foregroundStyle(MosaicTheme.ink)
                .accessibilityAddTraits(.isHeader)
            if let detail { Text(detail).foregroundStyle(MosaicTheme.muted) }
        }
        .accessibilityElement(children: .contain)
    }
}

struct MosaicPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.white : MosaicTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(
                isEnabled
                    ? MosaicTheme.deepGlaze.opacity(configuration.isPressed ? 0.82 : 1)
                    : MosaicTheme.claySurface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                if !isEnabled {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MosaicTheme.border, lineWidth: 1)
                }
            }
            .shadow(
                color: isEnabled ? MosaicTheme.warmShadow : .clear,
                radius: configuration.isPressed ? 2 : 6,
                y: configuration.isPressed ? 1 : 3
            )
            .scaleEffect(isEnabled && configuration.isPressed ? 0.985 : 1)
    }
}

struct MosaicSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? MosaicTheme.ink : MosaicTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 16)
            .background(isEnabled ? MosaicTheme.paper : MosaicTheme.claySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MosaicTheme.border, lineWidth: 1) }
            .opacity(isEnabled && configuration.isPressed ? 0.7 : 1)
    }
}

struct StatusPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(MosaicTheme.claySurface, in: Capsule())
    }
}

extension View {
    func mosaicField() -> some View {
        font(MosaicTheme.body())
            .frame(minHeight: 26, alignment: .leading)
            .padding(16)
            .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MosaicTheme.border) }
    }

    func mosaicAccessibilityAnnouncement(_ message: String?) -> some View {
        modifier(MosaicAccessibilityAnnouncement(message: message))
    }
}

private struct MosaicAccessibilityAnnouncement: ViewModifier {
    let message: String?

    func body(content: Content) -> some View {
        content.onChange(of: message) { _, newValue in
            guard UIAccessibility.isVoiceOverRunning,
                  let newValue,
                  !newValue.isEmpty else { return }
            UIAccessibility.post(notification: .announcement, argument: newValue)
        }
    }
}
