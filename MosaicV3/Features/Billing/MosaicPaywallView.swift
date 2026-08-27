import StoreKit
import SwiftUI

struct MosaicPaywallView: View {
    @Environment(MosaicAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isManagingSubscriptions = false

    var body: some View {
        @Bindable var billing = model.billing
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    LivingKilnHero(reduceMotion: reduceMotion, reduceTransparency: reduceTransparency)
                    Text("Make room for more people")
                        .font(MosaicTheme.display(34, weight: .semibold)).multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("Create a larger shared ritual while every participant keeps the complete Mosaic experience free.")
                        .foregroundStyle(MosaicTheme.muted).multilineTextAlignment(.center)
                    benefitList
                    packageChoices(billing)
                    actionArea(billing)
                    footer
                }
                .padding(.horizontal, 20).padding(.bottom, 30)
            }
            .porcelainBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Close paywall")
                }
            }
        }
        .manageSubscriptionsSheet(isPresented: $isManagingSubscriptions)
        .interactiveDismissDisabled(billing.actionState == .purchasing || billing.actionState == .synchronizing)
        .task { if billing.packages.isEmpty { await billing.reloadOfferings() } }
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 8) {
            benefit("Up to 100 ceramic tiles", "square.grid.3x3.fill")
            benefit("Up to 36 shots per member", "camera.fill")
            benefit("Multiple active Mosaics with Plus", "rectangle.stack.fill")
            benefit("Every handcrafted film look", "camera.filters")
        }.frame(maxWidth: .infinity, alignment: .leading).porcelainCard()
    }

    private func benefit(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon).font(.subheadline.weight(.semibold)).frame(minHeight: 44)
    }

    @ViewBuilder private func packageChoices(_ billing: BillingStore) -> some View {
        switch billing.loadState {
        case .idle, .loading:
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16).fill(MosaicTheme.raisedPaper).frame(height: 88)
                        .overlay { Text("Localized RevenueCat package").redacted(reason: .placeholder) }
                }
            }.accessibilityLabel("Loading purchase choices")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn’t load choices", systemImage: "wifi.exclamationmark")
            } description: { Text(message) } actions: {
                Button("Try again") { Task { await billing.reloadOfferings() } }.buttonStyle(MosaicSecondaryButtonStyle())
            }
        case .loaded:
            VStack(spacing: 12) {
                ForEach(billing.packages) { package in
                    PackageChoiceCard(
                        package: package,
                        selected: package.productIdentifier == billing.selectedProductID,
                        savingsPercent: package.kind == .annual ? billing.annualSavingsPercent : nil
                    ) { billing.selectedProductID = package.productIdentifier }
                }
            }
        }
    }

    @ViewBuilder private func actionArea(_ billing: BillingStore) -> some View {
        switch billing.actionState {
        case .pending:
            Label("Payment is pending approval. Access unlocks after the store and server confirm it.", systemImage: "clock.badge.checkmark")
                .font(.footnote).foregroundStyle(MosaicTheme.muted).porcelainCard()
        case .synchronizing:
            VStack(spacing: 12) {
                ProgressView(); Text("Confirming access with Mosaic…").font(.headline)
                Text("Premium controls unlock only after server confirmation.").font(.footnote).foregroundStyle(MosaicTheme.muted)
            }.frame(maxWidth: .infinity).porcelainCard()
        case .success:
            VStack(spacing: 12) {
                Image(systemName: "sparkles.square.filled.on.square").font(.system(size: 44)).foregroundStyle(MosaicTheme.accentForeground)
                Text("The kiln is open").font(MosaicTheme.display(25, weight: .semibold))
                Text(successDetail).font(.subheadline).foregroundStyle(MosaicTheme.muted).multilineTextAlignment(.center)
                Button("Continue creating") { dismiss() }.buttonStyle(MosaicPrimaryButtonStyle())
            }.frame(maxWidth: .infinity).porcelainCard()
        case .failed(let message):
            VStack(spacing: 12) { Text(message).font(.footnote).foregroundStyle(.red); purchaseButton(billing) }
        case .idle, .purchasing:
            purchaseButton(billing)
        }
    }

    private func purchaseButton(_ billing: BillingStore) -> some View {
        let package = billing.packages.first { $0.productIdentifier == billing.selectedProductID }
        return Button { Task { await billing.purchaseSelected() } } label: {
            HStack {
                if billing.actionState == .purchasing { ProgressView().tint(MosaicTheme.porcelain) }
                Text(buttonTitle(package))
            }.frame(maxWidth: .infinity)
        }
        .buttonStyle(MosaicPrimaryButtonStyle())
        .disabled(package == nil || billing.actionState == .purchasing)
        .accessibilityIdentifier("paywall.purchase")
    }

    private func buttonTitle(_ package: MonetizationPackage?) -> String {
        guard let package else { return "Choose an option" }
        return switch package.kind {
        case .annual: "Choose annual · \(package.localizedPrice)"
        case .monthly: "Choose monthly · \(package.localizedPrice)"
        case .eventPass: "Choose one Event Pass · \(package.localizedPrice)"
        }
    }

    private var successDetail: String {
        model.billing.snapshot.plusActive
            ? "Mosaic Plus is server-confirmed. Your premium creation choices are ready."
            : "Your Event Pass is server-confirmed and ready for one premium Mosaic."
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") { Task { await model.billing.restore() } }.frame(minHeight: 44)
            Button("Manage Subscriptions") { isManagingSubscriptions = true }
                .frame(minHeight: 44)
                .accessibilityLabel("Manage Subscriptions")
                .accessibilityIdentifier("paywall.manageSubscriptions")
            HStack(spacing: 24) {
                if let privacyURL = URL(string: "https://shellcat-com.github.io/Mosaic/privacy/") {
                    Link("Privacy", destination: privacyURL)
                }
                if let termsURL = URL(string: "https://shellcat-com.github.io/Mosaic/terms/") {
                    Link("Terms", destination: termsURL)
                }
            }.font(.footnote.weight(.semibold))
            Text("Mosaic Plus automatically renews unless canceled at least 24 hours before the current period ends. Your Apple Account is charged at confirmation and for renewal. An Event Pass is a one-time purchase used when you create one premium Mosaic without Plus.")
                .font(.caption).foregroundStyle(MosaicTheme.muted).multilineTextAlignment(.center)
        }
    }
}

private struct PackageChoiceCard: View {
    let package: MonetizationPackage
    let selected: Bool
    let savingsPercent: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title2)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(title).font(.headline)
                        if let savingsPercent { Text("SAVE \(savingsPercent)%").font(.caption2.bold()).padding(5).background(MosaicTheme.gold.opacity(0.25), in: Capsule()) }
                    }
                    Text(package.period).font(.caption).foregroundStyle(MosaicTheme.muted)
                    if let offer = package.introductoryOffer { Text(offer).font(.caption).foregroundStyle(MosaicTheme.accentForeground) }
                }
                Spacer(); Text(package.localizedPrice).font(.headline.monospacedDigit())
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 82)
            .background(selected ? MosaicTheme.sky.opacity(0.18) : MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(selected ? MosaicTheme.accentForeground : MosaicTheme.border, lineWidth: selected ? 2 : 1) }
        }
        .buttonStyle(.plain).accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("paywall.package.\(package.kind.rawValue)")
    }

    private var title: String {
        switch package.kind { case .annual: "Organizer Plus · Annual"; case .monthly: "Organizer Plus · Monthly"; case .eventPass: "One Event Pass" }
    }
}

private struct LivingKilnHero: View {
    let reduceMotion: Bool
    let reduceTransparency: Bool
    @State private var glowing = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30).fill(MosaicTheme.deepGlaze.gradient)
            ForEach(0..<12, id: \.self) { index in
                RoundedRectangle(cornerRadius: 7).fill(tileColor(index)).frame(width: 42, height: 42)
                    .overlay { RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(reduceTransparency ? 0.45 : 0.22)) }
                    .offset(x: CGFloat((index % 4) * 52 - 78), y: CGFloat((index / 4) * 52 - 52) + (glowing && !reduceMotion ? CGFloat((index % 2) * 4 - 2) : 0))
            }
        }
        .frame(height: 190)
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { glowing = true } } }
        .accessibilityElement(children: .ignore).accessibilityLabel("A glowing arrangement of ceramic tiles")
    }

    private func tileColor(_ index: Int) -> Color {
        [MosaicTheme.gold, MosaicTheme.rose, MosaicTheme.sky, MosaicTheme.sage][index % 4].opacity(glowing && !reduceMotion ? 0.98 : 0.86)
    }
}

struct MosaicPlusAccountCard: View {
    @Environment(MosaicAppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) { Text("Mosaic Plus").font(MosaicTheme.display(24, weight: .semibold)); Text(status).foregroundStyle(MosaicTheme.muted) }
                Spacer(); Image(systemName: model.billing.snapshot.plusActive ? "checkmark.seal.fill" : "flame.fill").font(.title2)
            }
            HStack { Label("Event Passes", systemImage: "ticket.fill"); Spacer(); Text("\(model.billing.snapshot.passBalance)").font(.headline.monospacedDigit()) }
            Button(model.billing.snapshot.plusActive ? "View options" : "Make room for more people") { model.billing.present(.account) }
                .buttonStyle(MosaicPrimaryButtonStyle())
            Button("Sync purchases") { Task { await model.billing.refreshServer() } }.frame(minHeight: 44)
        }.porcelainCard().accessibilityIdentifier("account.mosaicPlus")
    }

    private var status: String {
        let snapshot = model.billing.snapshot
        if snapshot.plusActive { return snapshot.expiresAt.map { "Active through \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Active · server confirmed" }
        return snapshot.passBalance > 0 ? "\(snapshot.passBalance) Event Pass ready" : "Free organizer"
    }
}
