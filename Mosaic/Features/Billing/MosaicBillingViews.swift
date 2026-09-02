import RevenueCatUI
import StoreKit
import SwiftUI

struct MosaicPaywallView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Fire bigger mosaics")
                    .font(MosaicTheme.display(30, weight: .semibold))
                Text(contextCopy)
                    .font(.subheadline)
                    .foregroundStyle(MosaicTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(MosaicTheme.canvas)

            if RevenueCatConfiguration.current != nil {
                PaywallView(displayCloseButton: true)
                    .onPurchaseCompleted { _ in
                        Task {
                            await store.refreshBilling(expectPremium: true)
                            store.isShowingPaywall = false
                            dismiss()
                        }
                    }
                    .onRestoreCompleted { _ in
                        Task {
                            await store.refreshBilling()
                            store.isShowingPaywall = false
                            dismiss()
                        }
                    }
                    .onPurchaseFailure { error in
                        store.accountMessage = error.localizedDescription
                    }
            } else {
                ContentUnavailableView(
                    "Billing setup required",
                    systemImage: "flame",
                    description: Text("Add the RevenueCat public SDK key for this build. The app refuses Test Store keys in Release.")
                )
                .frame(maxHeight: .infinity)
            }
        }
        .porcelainBackground()
    }

    private var contextCopy: String {
        switch store.paywallContext {
        case .customArtwork: "Custom artwork upload is coming later and is not available for purchase yet."
        case .collaborators: "Invite trusted admins and reviewers."
        case .additionalChallenge: "Run another active Mosaic alongside this one."
        case .recapEditor: "Approve and shape the community recap."
        case .hdArtwork, .posterExport: "Export the finished work at presentation quality."
        default: "More participants, custom acts, collaboration, and beautiful exports. Custom artwork upload is coming later."
        }
    }
}

struct BillingManagementView: View {
    @Environment(AppStore.self) private var store
    @State private var isRestoring = false
    @State private var isPurchasingPass = false

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                MosaicSectionHeader(title: "Billing", eyebrow: "Workspace owner", icon: .kiln)
                OrganicPanel(variant: .leaningLeft, tint: MosaicTheme.indigo.opacity(0.07)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(store.accessSnapshot.planName)
                                .font(MosaicTheme.display(28, weight: .semibold))
                            Spacer()
                            Text(store.accessSnapshot.subscriptionStatus.replacingOccurrences(of: "_", with: " ").uppercased())
                                .font(MosaicTheme.caption(.bold))
                                .foregroundStyle(MosaicTheme.indigo)
                        }
                        if let expiry = store.accessSnapshot.plusExpiresAt {
                            Text("\(store.accessSnapshot.willRenew ? "Renews" : "Access through") \(expiry.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline).foregroundStyle(MosaicTheme.muted)
                        }
                        Divider().overlay(MosaicTheme.border)
                        HStack {
                            Text("Unused Mosaic Passes")
                            Spacer()
                            Text("\(store.accessSnapshot.passBalance)").font(.headline)
                        }
                    }
                }

                Button(isRestoring ? "Restoring…" : "Restore Purchases") {
                    isRestoring = true
                    Task { await store.restorePurchases(); isRestoring = false }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isRestoring)

                Button(isPurchasingPass ? "Purchasing…" : "Buy one Mosaic Pass") {
                    isPurchasingPass = true
                    Task {
                        await store.purchaseEventPass()
                        isPurchasingPass = false
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isPurchasingPass)

                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    Label("Manage Apple subscription", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(SecondaryButtonStyle())

                if store.accessSnapshot.passBalance > 0 && !store.accessSnapshot.currentChallengeHasEventPass {
                    Button("Apply one Pass to this Mosaic") { Task { await store.redeemEventPass() } }
                        .buttonStyle(PrimaryButtonStyle())
                }

                Text("A Mosaic Pass is a purchased, non-expiring credit. Applying it is permanent for that Mosaic. Deleting your Mosaic account does not cancel an Apple subscription.")
                    .font(.footnote).foregroundStyle(MosaicTheme.muted)
                HStack {
                    Link("Privacy", destination: MosaicBuildConfiguration.privacyPolicyURL)
                    Spacer()
                    Link("Terms", destination: MosaicBuildConfiguration.termsURL)
                }
                .font(.footnote.weight(.semibold))
                if let message = store.accountMessage {
                    Text(message).font(.footnote).foregroundStyle(MosaicTheme.muted)
                }
            }
        }
        .navigationTitle("Billing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WorkspaceSettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var inviteRole: OrganizationRole = .reviewer
    @State private var showDeleteWorkspace = false
    @State private var newOwnerID = ""

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                MosaicSectionHeader(title: "Workspace", eyebrow: store.selectedOrganization?.role.rawValue.uppercased() ?? "ORGANIZATION", icon: .people)
                if store.organizations.count > 1 {
                    Picker("Organization", selection: Binding(
                        get: { store.selectedOrganizationID },
                        set: { value in if let value { Task { await store.selectOrganization(value) } } }
                    )) {
                        ForEach(store.organizations) { organization in
                            Text(organization.name).tag(Optional(organization.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                if store.selectedOrganization?.role.canManageChallenges == true {
                    OrganicPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Mosaic controls").font(.headline)
                            Label("Create and edit Mosaics", systemImage: "checkmark.circle")
                            Label("Manage participant invitations", systemImage: "checkmark.circle")
                        }
                    }
                }

                if store.selectedOrganization?.role.canManageCollaborators == true {
                    OrganicPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Collaborators").font(.headline)
                            Picker("Role", selection: $inviteRole) {
                                Text("Admin").tag(OrganizationRole.admin)
                                Text("Reviewer").tag(OrganizationRole.reviewer)
                            }.pickerStyle(.segmented)
                            if store.accessSnapshot.collaboratorLimit == 0 && !MosaicBuildConfiguration.billingEnabled {
                                Label("Collaborator invites are outside the hackathon build.", systemImage: "info.circle")
                                    .font(.footnote)
                                    .foregroundStyle(MosaicTheme.muted)
                            } else {
                                Button("Create seven-day invite") {
                                    if store.accessSnapshot.collaboratorLimit == 0 {
                                        store.requestPremium(.collaborators)
                                    } else {
                                        Task { await store.createCollaboratorInvite(role: inviteRole) }
                                    }
                                }.buttonStyle(SecondaryButtonStyle())
                            }
                            if let url = store.latestCollaboratorInvite {
                                ShareLink(item: url) { Label("Share single-use link", systemImage: "square.and.arrow.up") }
                            }
                        }
                    }
                }

                if MosaicBuildConfiguration.billingEnabled,
                   store.selectedOrganization?.role.canManageBilling == true {
                    NavigationLink { BillingManagementView() } label: {
                        Label("Billing and Mosaic Passes", systemImage: "creditcard")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }.buttonStyle(SecondaryButtonStyle())

                    OrganicPanel(variant: .softRectangle) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ownership").font(.headline)
                            TextField("Collaborator user UUID", text: $newOwnerID)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                            Button("Transfer ownership") {
                                guard let id = UUID(uuidString: newOwnerID) else {
                                    store.accountMessage = "Enter a collaborator’s valid user UUID."
                                    return
                                }
                                Task { await store.transferSelectedOrganization(to: id) }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            Text("The new owner must already be a collaborator. App Store subscriptions do not transfer, and purchased PASS credits must be redeemed first.")
                                .font(.footnote).foregroundStyle(MosaicTheme.muted)
                            Button("Delete workspace", role: .destructive) { showDeleteWorkspace = true }
                        }
                    }
                }
            }
        }
        .navigationTitle("Workspace")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this workspace and all of its Mosaics?", isPresented: $showDeleteWorkspace) {
            Button("Delete workspace", role: .destructive) { Task { await store.deleteSelectedOrganization() } }
        } message: {
            Text("This cannot be undone. Deleting a workspace does not cancel an App Store subscription.")
        }
    }
}
