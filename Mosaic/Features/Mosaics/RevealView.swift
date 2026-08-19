import SwiftUI

struct RevealView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var verifiedCount: Int { store.challenge.contributions.filter { $0.evidence != .reflection }.count }
    var selfAttestedCount: Int { store.challenge.contributions.filter { $0.evidence == .reflection }.count }
    var memories: Int { store.challenge.contributions.filter(\.sharedMemory).count }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.13, green: 0.08, blue: 0.045), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        if phase < 2 {
                            Button("Reveal now") {
                                withAnimation(.easeOut(duration: 0.25)) { phase = 2 }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                        }
                        Spacer()
                        Button("Close", systemImage: "xmark") { dismiss() }
                            .labelStyle(.iconOnly)
                            .font(.headline).foregroundStyle(.white)
                            .frame(width: 42, height: 42).background(.ultraThinMaterial, in: Circle())
                    }

                    Text(phase >= 1 ? "Together, we made this" : "The kiln is opening")
                        .font(MosaicTheme.display(40, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    ZStack {
                        Circle()
                            .fill(MosaicTheme.gold.opacity(phase >= 1 ? 0.24 : 0.04))
                            .blur(radius: 18)
                        MosaicBoard(contributions: Array(store.challenge.contributions.prefix(25)), columns: 5, tileSize: 56)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(MosaicTheme.gold.opacity(phase >= 2 ? 0.9 : 0.2), lineWidth: 3))
                            .shadow(color: MosaicTheme.gold.opacity(phase >= 1 ? 0.55 : 0), radius: 28)
                            .saturation(phase >= 1 ? 1 : 0.05)
                            .blur(radius: phase >= 1 ? 0 : 9)
                        if phase >= 1 {
                            DoodleIcon(icon: .kintsugi, color: MosaicTheme.gold, lineWidth: 3)
                                .frame(width: 74, height: 74)
                                .offset(x: 126, y: -115)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(height: 330)
                    .animation(.easeInOut(duration: reduceMotion ? 0.2 : 1.8), value: phase)

                    if phase >= 2 {
                        impactReceipt
                            .transition(.opacity.combined(with: reduceMotion ? .identity : .move(edge: .bottom)))
                    }

                    if phase >= 2 {
                        ShareLink(item: "Our community completed \(store.challenge.contributions.count) acts of kindness in \(store.challenge.name).") {
                            Label("Share the impact", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.indigo))
                    }
                }
                .padding(20)
            }
        }
        .task {
            if reduceMotion {
                phase = 2
            } else {
                try? await Task.sleep(for: .seconds(0.7))
                guard phase < 2 else { return }
                phase = 1
                try? await Task.sleep(for: .seconds(2.2))
                guard phase < 2 else { return }
                withAnimation(.easeOut(duration: 0.7)) { phase = 2 }
            }
        }
    }

    private var impactReceipt: some View {
        VStack(spacing: 18) {
            MosaicSticker(kind: .sparkles, size: 58)
            Text("Impact Receipt").font(MosaicTheme.display(31, weight: .semibold))
            Divider()
            receiptRow("Verified or confirmed", "\(verifiedCount)")
            receiptRow("Self-attested reflections", "\(selfAttestedCount)")
            receiptRow("Approved memories", "\(memories)")
            receiptRow("Revived chains", "\(store.challenge.contributions.filter(\.isRevived).count)")
            Text("Thank you for making kindness stick.")
                .font(.footnote).foregroundStyle(MosaicTheme.muted).padding(.top, 5)
        }
        .foregroundStyle(MosaicTheme.ink)
        .porcelainCard()
    }

    private func receiptRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).fontWeight(.semibold) }
            .font(.subheadline)
    }
}
