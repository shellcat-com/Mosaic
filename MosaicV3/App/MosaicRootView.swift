import SwiftUI

struct MosaicRootView: View {
    @Environment(MosaicAppModel.self) private var model

    var body: some View {
        Group {
            switch model.session.phase {
            case .restoring:
                ProgressView("Opening Mosaic…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .porcelainBackground()
            case .signedOut:
                SignInView(invitationCode: model.router.pendingInvitationCode)
            case .needsDisplayName:
                DisplayNameView()
            case .ready:
                MosaicTabView()
            case .unavailable:
                AuthenticationRecoveryView()
            }
        }
        .tint(MosaicTheme.accentForeground)
        .task(id: model.session.userID) {
            if model.session.isReady {
                await model.configureAuthenticatedServices()
                await model.library.refresh()
            }
        }
    }
}

private struct AuthenticationRecoveryView: View {
    @Environment(MosaicAppModel.self) private var model

    var body: some View {
        MosaicPage {
            VStack(alignment: .leading, spacing: 22) {
                MosaicTitle(
                    "Mosaic couldn't connect.",
                    eyebrow: "Your account is still safe",
                    detail: model.session.message ?? "Check your connection and try again."
                )
                Button("Try again") {
                    Task { await model.session.retry() }
                }
                .buttonStyle(MosaicPrimaryButtonStyle())
                Button("Sign out") {
                    Task { await model.signOut() }
                }
                .buttonStyle(MosaicSecondaryButtonStyle())
            }
        }
    }
}

struct MosaicTabView: View {
    @Environment(MosaicAppModel.self) private var model

    var body: some View {
        @Bindable var router = model.router
        TabView(selection: $router.selectedTab) {
            Tab("Mosaics", systemImage: "square.grid.2x2", value: MosaicTab.mosaics) {
                NavigationStack(path: $router.mosaicsPath) {
                    MosaicsHomeView(path: $router.mosaicsPath)
                        .navigationDestination(for: MosaicRoute.self) { route in
                            MosaicDestinationView(route: route, path: $router.mosaicsPath)
                        }
                }
            }
            Tab("Camera", systemImage: "camera.fill", value: MosaicTab.camera) {
                NavigationStack { EventCameraView() }
            }
            Tab("You", systemImage: "person.crop.circle", value: MosaicTab.you) {
                NavigationStack(path: $router.youPath) {
                    YouView(path: $router.youPath)
                        .navigationDestination(for: MosaicRoute.self) { route in
                            MosaicDestinationView(route: route, path: $router.youPath)
                        }
                }
            }
        }
        .task(id: router.pendingInvitationCode) {
            router.openPendingInvitation()
        }
        .sheet(isPresented: Binding(
            get: { model.billing.isShowingPaywall },
            set: { model.billing.isShowingPaywall = $0 }
        )) {
            MosaicPaywallView()
                .environment(model)
        }
    }
}

private struct MosaicDestinationView: View {
    let route: MosaicRoute
    @Binding var path: [MosaicRoute]

    var body: some View {
        switch route {
        case .create: CreateMosaicView(path: $path)
        case .join(let code): JoinMosaicView(prefilledCode: code, path: $path)
        case .event(let id): MosaicEventView(eventID: id, path: $path)
        case .editEvent(let id): EditMosaicView(eventID: id, path: $path)
        case .activity(let id): KindnessActivityView(activityID: id)
        case .contribution(let id): ContributionDetailView(contributionID: id)
        case .photo(let id): EventPhotoDetailView(photoID: id)
        case .recap(let id): PhotoRecapBuilderView(eventID: id)
        case .blockedUsers: BlockedUsersView()
        }
    }
}
