import SwiftUI

struct ContributionHubView: View {
    @Environment(AppStore.self) private var store
    @Environment(MosaicRouter.self) private var router

    private var isRevealed: Bool {
        store.challenge.revealedAt != nil || store.challenge.serverStatus == "revealed"
    }

    private var approvedMemoryCount: Int {
        store.challenge.sharedMoments.filter { $0.lifecycle == .approved }.count
    }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: 24) {
                header
                if isRevealed {
                    completedState
                } else if store.challenge.isShowcase {
                    readOnlyShowcaseState
                } else {
                    contributionChoices
                    contributionStatus
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add to your Mosaic")
                .font(MosaicTheme.display(40, weight: .semibold))
            Text(store.challenge.name)
                .font(.headline)
                .foregroundStyle(MosaicTheme.indigo)
            Text("An act builds the artwork. A memory helps tell the story.")
                .font(.body)
                .foregroundStyle(MosaicTheme.muted)
        }
    }

    private var contributionChoices: some View {
        VStack(spacing: 16) {
            contributionCard(
                title: "Complete an act",
                detail: "Choose a small act of kindness. Once it is verified, it becomes one ceramic tile.",
                button: "Choose an act",
                icon: .tile,
                tint: MosaicTheme.persimmon
            ) {
                router.showMissions(for: store.challenge.id)
            }

            contributionCard(
                title: "Add a memory",
                detail: "Share a photo, short video, or note for the private reveal and recap.",
                button: "Add a memory",
                icon: .memory,
                tint: MosaicTheme.indigo
            ) {
                router.showMemoryComposer(for: store.challenge.id)
            }
        }
    }

    private func contributionCard(
        title: String,
        detail: String,
        button: String,
        icon: MosaicIcon,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        OrganicPanel(variant: .softRectangle, tint: tint.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 12) {
                DoodleIcon(icon: icon, color: tint)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
                Text(title)
                    .font(MosaicTheme.display(28, weight: .semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(MosaicTheme.muted)
                Button(button, action: action)
                    .buttonStyle(PrimaryButtonStyle(color: tint))
            }
        }
    }

    private var contributionStatus: some View {
        OrganicPanel(variant: .softRectangle, tint: MosaicTheme.claySurface) {
            VStack(alignment: .leading, spacing: 12) {
                MosaicSectionHeader(title: "Your contribution", eyebrow: "Current Mosaic", icon: .spark)
                HStack(spacing: 8) {
                    MetricPill(icon: "square.fill", text: "\(store.challenge.contributions.count) tiles")
                    MetricPill(icon: "photo.on.rectangle", text: "\(approvedMemoryCount) memories")
                }
                Button("View your memories") {
                    router.showMemories()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var readOnlyShowcaseState: some View {
        OrganicPanel(variant: .leaningLeft, tint: MosaicTheme.indigo.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 16) {
                Label("READ-ONLY SHOWCASE", systemImage: "lock.fill")
                    .font(MosaicTheme.caption(.bold))
                    .tracking(0.8)
                    .foregroundStyle(MosaicTheme.indigo)
                Text("Create in your private Mosaic")
                    .font(MosaicTheme.display(28, weight: .semibold))
                Text("The shared showcase is a finished example, so it cannot accept evidence or memories.")
                    .font(.subheadline)
                    .foregroundStyle(MosaicTheme.muted)
                if let challengeID = store.writableContributionChallengeID {
                    Button("Open my private Mosaic") {
                        router.showMissions(for: challengeID)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("Reconnect and choose Explore Demo to prepare a private sandbox.")
                        .font(.footnote)
                        .foregroundStyle(MosaicTheme.muted)
                }
            }
        }
    }

    private var completedState: some View {
        OrganicPanel(variant: .leaningLeft, tint: MosaicTheme.gold.opacity(0.12)) {
            VStack(alignment: .leading, spacing: 16) {
                MosaicSticker(kind: .sparkles, size: 64)
                Text("This Mosaic has been revealed")
                    .font(MosaicTheme.display(30, weight: .semibold))
                Text("Contributions are closed. The finished artwork, memories, and recap are ready in Mosaics.")
                    .font(.subheadline)
                    .foregroundStyle(MosaicTheme.muted)
                Button("View in Mosaics") {
                    router.select(.groups)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

// MARK: - Kindness Roll (experience version 2)

struct GroupsLibraryView: View {
    @Environment(AppStore.self) private var store

    private var active: [ChallengeSummary] {
        store.challengeLibrary.filter { $0.revealedAt == nil && $0.serverStatus != "revealed" }
    }

    private var revealed: [ChallengeSummary] {
        store.challengeLibrary.filter { $0.revealedAt != nil || $0.serverStatus == "revealed" }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your groups")
                        .font(MosaicTheme.display(40, weight: .semibold))
                    Text("Every group is one shared roll. Add a kind moment now; open everything together later.")
                        .font(MosaicTheme.body())
                        .foregroundStyle(MosaicTheme.muted)
                }

                groupSection("ACTIVE", groups: active, empty: "No active kindness rolls")
                groupSection("REVEALED", groups: revealed, empty: "Revealed groups will live here")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(MosaicTheme.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await store.refreshLibrary() }
    }

    @ViewBuilder
    private func groupSection(_ title: String, groups: [ChallengeSummary], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(MosaicTheme.caption(.bold))
                .tracking(1.2)
                .foregroundStyle(MosaicTheme.muted)
            if groups.isEmpty {
                Text(empty)
                    .font(MosaicTheme.body())
                    .foregroundStyle(MosaicTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                    .padding(18)
                    .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                ForEach(groups) { summary in
                    NavigationLink {
                        if summary.experienceVersion == .kindnessRoll {
                            KindnessRollFolderView(summary: summary)
                        } else {
                            EventDetailView(summary: summary)
                        }
                    } label: {
                        KindnessGroupFolderCard(summary: summary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct KindnessGroupFolderCard: View {
    let summary: ChallengeSummary

    private var revealed: Bool { summary.revealedAt != nil || summary.serverStatus == "revealed" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.name)
                        .font(MosaicTheme.display(28, weight: .semibold))
                        .foregroundStyle(MosaicTheme.ink)
                    Text(summary.groupName)
                        .font(MosaicTheme.caption(.medium))
                        .foregroundStyle(MosaicTheme.muted)
                }
                Spacer()
                Image(systemName: revealed ? "sparkles" : "lock.fill")
                    .foregroundStyle(revealed ? MosaicTheme.gold : MosaicTheme.indigo)
                    .frame(width: 44, height: 44)
                    .background((revealed ? MosaicTheme.gold : MosaicTheme.indigo).opacity(0.1), in: Circle())
            }

            HStack(spacing: 12) {
                Label("\(summary.contributionCount)/\(summary.goal) acts", systemImage: "square.grid.3x3.fill")
                Spacer()
                if revealed {
                    Text("OPEN")
                } else {
                    Text(summary.revealAt, style: .relative)
                }
            }
            .font(MosaicTheme.caption(.bold))
            .foregroundStyle(revealed ? MosaicTheme.gold : MosaicTheme.indigo)

            ProgressView(value: min(Double(summary.contributionCount) / Double(max(summary.goal, 1)), 1))
                .tint(revealed ? MosaicTheme.gold : MosaicTheme.indigo)
        }
        .padding(20)
        .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MosaicTheme.border.opacity(0.7), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the group folder")
    }
}

struct KindnessRollFolderView: View {
    let summary: ChallengeSummary

    @Environment(AppStore.self) private var store
    @Environment(MosaicRouter.self) private var router
    @State private var loaded = false

    private var group: KindnessChallenge { store.challenge }
    private var revealed: Bool { group.revealedAt != nil || group.serverStatus == "revealed" }
    private var moments: [SharedMoment] {
        group.sharedMoments.filter { $0.lifecycle != .deleted && $0.lifecycle != .rejected }
    }

    var body: some View {
        ScrollView {
            if loaded {
                VStack(alignment: .leading, spacing: 24) {
                    folderHeader
                    artworkCard
                    contactSheet
                    if revealed { revealedArtifacts }
                    else { addAction }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            } else {
                ProgressView("Opening group…")
                    .frame(maxWidth: .infinity, minHeight: 360)
            }
        }
        .background(MosaicTheme.canvas)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: summary.id) {
            if store.challenge.id != summary.id { await store.openChallenge(summary.id) }
            loaded = true
        }
        .toolbar {
            if store.isOrganizer {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.showOrganizer(returnTo: summary.id) } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Group settings")
                }
            }
        }
    }

    private var folderHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(revealed ? "REVEALED TOGETHER" : "SEALED UNTIL REVEAL")
                .font(MosaicTheme.caption(.bold))
                .tracking(1.1)
                .foregroundStyle(revealed ? MosaicTheme.gold : MosaicTheme.indigo)
            Text(group.name)
                .font(MosaicTheme.display(42, weight: .semibold))
            Text(group.purpose)
                .font(MosaicTheme.body())
                .foregroundStyle(MosaicTheme.muted)
            if !revealed {
                Label {
                    Text("Reveals ") + Text(group.revealDate, style: .relative)
                } icon: { Image(systemName: "timer") }
                .font(MosaicTheme.body(.semibold))
                .foregroundStyle(MosaicTheme.indigo)
            }
        }
        .padding(.top, 16)
    }

    private var artworkCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(revealed ? "The artwork" : "Artwork in progress")
                    .font(MosaicTheme.display(25, weight: .semibold))
                Spacer()
                Text("\(group.contributions.count)/\(group.goal)")
                    .font(MosaicTheme.caption(.bold))
                    .foregroundStyle(MosaicTheme.indigo)
            }
            KindnessArtworkMask(
                total: max(group.goal, 1),
                filled: Set(group.contributions.compactMap(\.tilePosition)),
                revealed: revealed
            )
            .frame(height: 220)
            if revealed && group.contributions.count < group.goal {
                Text("Unfilled spaces remain part of what this group made.")
                    .font(MosaicTheme.caption())
                    .foregroundStyle(MosaicTheme.muted)
            }
        }
        .padding(18)
        .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var contactSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(revealed ? "Group roll" : "Sealed contact sheet")
                    .font(MosaicTheme.display(25, weight: .semibold))
                Spacer()
                Text("\(moments.count) moments")
                    .font(MosaicTheme.caption(.medium))
                    .foregroundStyle(MosaicTheme.muted)
            }
            if moments.isEmpty {
                Text("The first kind moment will appear here—locked until reveal.")
                    .font(MosaicTheme.body())
                    .foregroundStyle(MosaicTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(moments) { moment in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(revealed ? MosaicTheme.claySurface : MosaicTheme.ink)
                            Image(systemName: revealed ? moment.mediaKind.symbol : "lock.fill")
                                .foregroundStyle(revealed ? MosaicTheme.indigo : .white.opacity(0.78))
                            if moment.lifecycle == .uploadPending {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundStyle(MosaicTheme.gold)
                                    .padding(6)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            }
                        }
                        .aspectRatio(0.8, contentMode: .fit)
                        .accessibilityLabel(moment.lifecycle == .uploadPending
                            ? "Protected moment waiting to upload"
                            : (revealed ? "\(moment.mediaKind.rawValue) moment" : "Locked moment"))
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await store.deleteSharedMoment(moment.id) }
                            } label: {
                                Label(revealed ? "Remove from gallery and recap" : "Withdraw contribution", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var addAction: some View {
        Button {
            router.select(.camera)
            router.showMemoryComposer(for: group.id)
        } label: {
            Label("Add an act", systemImage: "camera.fill")
        }
        .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.indigo))
        .disabled(group.summary.phase() != .active)
    }

    private var revealedArtifacts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your group made")
                .font(MosaicTheme.display(28, weight: .semibold))
            artifactButton("Completed artwork", icon: "square.grid.3x3.fill") { router.showReveal(for: group.id) }
            artifactButton("Photo & video gallery", icon: "photo.on.rectangle.angled") { router.showMemories() }
            artifactButton("Automatic recap", icon: "play.rectangle.fill") { router.showRecap(for: group.id) }
        }
    }

    private func artifactButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(MosaicTheme.body(.semibold))
            .padding(18)
            .foregroundStyle(MosaicTheme.ink)
            .background(MosaicTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct KindnessArtworkMask: View {
    let total: Int
    let filled: Set<Int>
    let revealed: Bool

    private var side: Int { max(1, Int(ceil(sqrt(Double(total))))) }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: side), spacing: 4) {
            ForEach(0..<(side * side), id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fill(for: index))
                    .overlay {
                        if !filled.contains(index) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(MosaicTheme.border.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3]))
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .blur(radius: revealed ? 0 : 7)
        .overlay {
            if !revealed {
                Label("Hidden until reveal", systemImage: "lock.fill")
                    .font(MosaicTheme.caption(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .clipped()
    }

    private func fill(for index: Int) -> Color {
        guard index < total, filled.contains(index) else { return MosaicTheme.canvas }
        let palette = [MosaicTheme.indigo, MosaicTheme.sage, MosaicTheme.persimmon, MosaicTheme.gold]
        return revealed ? palette[index % palette.count].opacity(0.82) : MosaicTheme.indigo.opacity(0.4)
    }
}

struct KindnessCameraTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(MosaicRouter.self) private var router
    @State private var selectedGroupID: UUID?

    private var activeGroups: [ChallengeSummary] {
        let groups = store.challengeLibrary.filter {
            $0.experienceVersion == .kindnessRoll && !$0.isShowcase && $0.phase() == .active
        }
        if groups.isEmpty,
           store.challenge.experienceVersion == .kindnessRoll,
           !store.challenge.isShowcase,
           store.challenge.summary.phase() == .active {
            return [store.challenge.summary]
        }
        return groups
    }

    private var selectedGroup: ChallengeSummary? {
        activeGroups.first(where: { $0.id == selectedGroupID }) ?? activeGroups.first
    }

    private var lookAccent: Color {
        switch selectedGroup?.filmLookID ?? .sunwashed {
        case .sunwashed: MosaicTheme.gold
        case .garden: MosaicTheme.sage
        case .afterglow: MosaicTheme.rose
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.055, green: 0.05, blue: 0.045)
                    .ignoresSafeArea()

                if let selectedGroup {
                    cameraHome(for: selectedGroup, availableHeight: proxy.size.height)
                } else {
                    emptyCamera
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { repairSelection() }
        .onChange(of: activeGroups.map(\.id)) { _, _ in repairSelection() }
    }

    private func cameraHome(for group: ChallengeSummary, availableHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            cameraTopBar(group)

            ZStack {
                LinearGradient(
                    colors: [lookAccent.opacity(0.22), Color.black, Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Canvas { context, size in
                    for index in 0..<42 {
                        let x = CGFloat((index * 47) % 101) / 101 * size.width
                        let y = CGFloat((index * 71) % 103) / 103 * size.height
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(.white.opacity(0.16))
                        )
                    }
                }
                .accessibilityHidden(true)

                viewfinderCorners

                VStack(spacing: 8) {
                    Spacer()
                    Text(group.name)
                        .font(MosaicTheme.display(34, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text("One act. One moment. Sealed until reveal.")
                        .font(MosaicTheme.caption(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                    Spacer()
                    HStack(spacing: 8) {
                        cameraHint("Choose an act", icon: "square.stack.3d.up.fill")
                        cameraHint("Capture privately", icon: "lock.fill")
                    }
                }
                .padding(24)
            }
            .foregroundStyle(.white)
            .frame(height: max(260, availableHeight * 0.43))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            groupSelector
                .padding(.top, 16)

            captureControls(group)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func cameraTopBar(_ group: ChallengeSummary) -> some View {
        HStack(spacing: 12) {
            Label("PRIVATE", systemImage: "lock.fill")
                .font(MosaicTheme.caption(.bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.74))

            Spacer()

            VStack(spacing: 2) {
                Text("MOSAIC CAMERA")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.4)
                Text(group.filmLookID.title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(lookAccent)
            }

            Spacer()

            Menu {
                ForEach(activeGroups) { item in
                    Button {
                        selectedGroupID = item.id
                    } label: {
                        if item.id == group.id {
                            Label(item.name, systemImage: "checkmark")
                        } else {
                            Text(item.name)
                        }
                    }
                }
            } label: {
                Image(systemName: "square.stack.3d.up")
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("Choose a group")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var groupSelector: some View {
        VStack(spacing: 8) {
            HStack {
                Text("YOUR ACTIVE ROLLS")
                    .font(MosaicTheme.caption(.bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("Swipe to choose")
                    .font(MosaicTheme.caption())
                    .foregroundStyle(.white.opacity(0.42))
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(activeGroups) { group in
                        let isSelected = group.id == selectedGroup?.id
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedGroupID = group.id
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: group.filmLookID == .garden ? "leaf.fill" : "camera.aperture")
                                    Spacer()
                                    Text("\(group.contributionCount)/\(group.goal)")
                                }
                                .font(MosaicTheme.caption(.bold))
                                Text(group.name)
                                    .font(MosaicTheme.body(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(isSelected ? MosaicTheme.ink : Color.white)
                            .frame(width: 132, alignment: .leading)
                            .padding(12)
                            .background(isSelected ? MosaicTheme.paper : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isSelected ? lookAccent : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func captureControls(_ group: ChallengeSummary) -> some View {
        HStack(spacing: 32) {
            Button {
                router.select(.groups)
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .accessibilityLabel("Browse groups")

            Button {
                router.showMemoryComposer(for: group.id)
            } label: {
                ZStack {
                    Circle().fill(MosaicTheme.paper)
                    Circle().stroke(lookAccent, lineWidth: 4).padding(8)
                }
                .frame(width: 84, height: 84)
                .shadow(color: lookAccent.opacity(0.28), radius: 16, y: 8)
            }
            .accessibilityLabel("Open camera for \(group.name)")
            .accessibilityHint("Choose an act, then capture a sealed moment")

            Button {
                Task {
                    if store.challenge.id != group.id { await store.openChallenge(group.id) }
                    router.showMemories()
                }
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .accessibilityLabel("View sealed moments")
        }
        .foregroundStyle(.white)
    }

    private var viewfinderCorners: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [16, 220]))
                .padding(20)
            Image(systemName: "viewfinder")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(lookAccent.opacity(0.7))
        }
        .accessibilityHidden(true)
    }

    private func cameraHint(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(MosaicTheme.caption(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.42), in: Capsule())
    }

    private var emptyCamera: some View {
        VStack(spacing: 20) {
            Spacer()
            MosaicSticker(kind: .sparkles, size: 72)
            Text("Your camera needs a group")
                .font(MosaicTheme.display(36, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Join or create an active Mosaic, then come back to capture one kind moment.")
                .font(MosaicTheme.body())
                .foregroundStyle(.white.opacity(0.64))
                .multilineTextAlignment(.center)
            Button("Browse groups") { router.select(.groups) }
                .buttonStyle(PrimaryButtonStyle(color: MosaicTheme.gold))
            Spacer()
        }
        .padding(24)
    }

    private func repairSelection() {
        guard !activeGroups.isEmpty else {
            selectedGroupID = nil
            return
        }
        if !activeGroups.contains(where: { $0.id == selectedGroupID }) {
            selectedGroupID = activeGroups.first?.id
        }
    }
}

private extension SharedMomentMediaKind {
    var symbol: String {
        switch self {
        case .photo: "photo.fill"
        case .video: "video.fill"
        case .note: "text.quote"
        }
    }
}
