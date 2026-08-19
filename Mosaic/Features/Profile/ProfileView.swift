import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You")
                            .font(MosaicTheme.display(42, weight: .semibold))
                        Text("Your private place in the mosaic.")
                            .font(.subheadline)
                            .foregroundStyle(MosaicTheme.muted)
                    }
                    Spacer()
                    MosaicSticker(kind: .helpingHands, size: 58)
                }

                identityCard
                kindnessCard
                settingsCard

                Label {
                    Text("Mosaic has no public profiles, likes, follower counts, or leaderboards.")
                } icon: {
                    DoodleIcon(icon: .memory, color: MosaicTheme.muted)
                        .frame(width: 20, height: 20)
                }
                .font(.footnote)
                .foregroundStyle(MosaicTheme.muted)
                .padding(.horizontal, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var identityCard: some View {
        OrganicPanel(variant: .leaningRight, tint: MosaicTheme.sage.opacity(0.12)) {
            HStack(spacing: 16) {
                DoodleIcon(icon: .profile, color: MosaicTheme.sage, lineWidth: 2.5)
                    .frame(width: 48, height: 48)
                    .frame(width: 68, height: 68)
                    .background(MosaicTheme.paper, in: Circle())
                    .overlay(Circle().stroke(MosaicTheme.sage.opacity(0.5), lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.displayName.isEmpty ? "Guest participant" : store.displayName)
                        .font(MosaicTheme.display(25, weight: .semibold))
                    Text(store.privacyMode)
                        .font(.subheadline)
                        .foregroundStyle(MosaicTheme.muted)
                }
            }
        }
    }

    private var kindnessCard: some View {
        OrganicPanel(variant: .leaningLeft) {
            VStack(alignment: .leading, spacing: 18) {
                MosaicSectionHeader(title: "Your kindness", eyebrow: "Quiet impact", icon: .heart)
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 0) {
                        accessibilityStatistic(value: store.pendingContribution == nil ? "0" : "1", label: "Tiles placed")
                        Divider().overlay(MosaicTheme.border)
                        accessibilityStatistic(value: store.pendingContribution?.sharedMemory == true ? "1" : "0", label: "Memories shared")
                        Divider().overlay(MosaicTheme.border)
                        accessibilityStatistic(value: "0", label: "Invites accepted")
                    }
                } else {
                    HStack(spacing: 8) {
                        statistic(value: store.pendingContribution == nil ? "0" : "1", label: "Tiles placed")
                        statistic(value: store.pendingContribution?.sharedMemory == true ? "1" : "0", label: "Memories shared")
                        statistic(value: "0", label: "Invites accepted")
                    }
                }
                if let contribution = store.pendingContribution, contribution.status == .verified {
                    Divider().overlay(MosaicTheme.border)
                    NavigationLink {
                        TileFiringView(contribution: contribution)
                    } label: {
                        Label("Fire and place your verified tile", systemImage: "flame.fill")
                            .font(.headline)
                            .foregroundStyle(MosaicTheme.persimmon)
                    }
                } else if store.pendingContribution?.status == .pendingReview {
                    Divider().overlay(MosaicTheme.border)
                    Label("Your latest evidence is waiting for organizer review.", systemImage: "clock.badge.checkmark")
                        .font(.footnote)
                        .foregroundStyle(MosaicTheme.muted)
                }
            }
        }
    }

    private var settingsCard: some View {
        OrganicPanel(variant: .softRectangle) {
            VStack(spacing: 0) {
                NavigationLink {
                    ConsentCenterView()
                } label: {
                    settingsRow("Privacy & consent", icon: .heart)
                }
                Divider().overlay(MosaicTheme.border)
                settingsRow("Contribution recovery", icon: .chain)
                Divider().overlay(MosaicTheme.border)
                settingsRow("Accessibility", icon: .people)
                Divider().overlay(MosaicTheme.border)
                settingsRow("About Mosaic", icon: .mosaic)
            }
        }
    }

    private func statistic(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(MosaicTheme.display(34, weight: .semibold))
            Text(label)
                .font(MosaicTheme.caption())
                .foregroundStyle(MosaicTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accessibilityStatistic(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(value)
                .font(MosaicTheme.display(32, weight: .semibold))
                .frame(minWidth: 44, alignment: .leading)
            Text(label)
                .font(.body)
            Spacer()
        }
        .frame(minHeight: 64)
    }

    private func settingsRow(_ title: String, icon: MosaicIcon) -> some View {
        HStack(spacing: 13) {
            DoodleIcon(icon: icon, color: MosaicTheme.ink.opacity(0.78))
                .frame(width: 23, height: 23)
            Text(title)
                .font(MosaicTheme.body(.medium))
                .foregroundStyle(MosaicTheme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(MosaicTheme.muted)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

struct ConsentCenterView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 22) {
                MosaicSectionHeader(title: "Privacy & consent", eyebrow: "You stay in control", icon: .heart)

                OrganicPanel {
                    VStack(spacing: 0) {
                        consentRow("Evidence visibility", "Organizer only")
                        Divider().overlay(MosaicTheme.border)
                        consentRow("Identity", store.privacyMode)
                        Divider().overlay(MosaicTheme.border)
                        consentRow("Community memory", store.pendingContribution?.sharedMemory == true ? "Included" : "Not included")
                        Divider().overlay(MosaicTheme.border)
                        consentRow("Export consent", "Not granted")
                    }
                }

                Label("Evidence and story consent are separate. Removing a contribution also removes it from impact totals without exposing a public reason.", systemImage: "lock.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(MosaicTheme.muted)
                    .padding(.horizontal, 4)
            }
        }
        .navigationTitle("Privacy & consent")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func consentRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(value).font(.footnote).foregroundStyle(MosaicTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }
}
