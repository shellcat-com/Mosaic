import SwiftUI

struct MosaicsHomeView: View {
    @Environment(MosaicAppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var path: [MosaicRoute]

    var body: some View {
        MosaicPage {
            VStack(alignment: .leading, spacing: 20) {
                if let hero = model.library.active.first {
                    LivingKilnHero(event: hero)
                    if model.library.active.count > 1 {
                        eventSection(title: "More happening now", events: Array(model.library.active.dropFirst()), empty: "")
                    }
                } else {
                    emptyLibrary
                }
                eventSection(title: "Revealed", events: model.library.completed, empty: "Finished artwork and photo galleries will collect here.")
                if let message = model.library.message {
                    Text(message).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Mosaics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Join", systemImage: "qrcode") { path.append(.join(prefilledCode: nil)) }
                Button("Create", systemImage: "plus") { path.append(.create) }
            }
        }
        .refreshable { await model.library.refresh() }
    }

    private var emptyLibrary: some View {
        VStack(alignment: .leading, spacing: 16) {
            MosaicTitle("Make something together", eyebrow: "Your first Mosaic", detail: "Create a shared kindness experience or join one with an invitation.")
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { emptyActions }
            } else {
                HStack(spacing: 12) { emptyActions }
            }
        }
        .porcelainCard()
    }

    @ViewBuilder private var emptyActions: some View {
        Button("Create Mosaic") { path.append(.create) }.buttonStyle(MosaicPrimaryButtonStyle())
        Button("Join Mosaic") { path.append(.join(prefilledCode: nil)) }.buttonStyle(MosaicSecondaryButtonStyle())
    }

    @ViewBuilder
    private func eventSection(title: String, events: [MosaicSummary], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(MosaicTheme.display(24, weight: .semibold))
            if events.isEmpty {
                Text(empty).foregroundStyle(MosaicTheme.muted).porcelainCard()
            } else {
                ForEach(events) { event in
                    NavigationLink(value: MosaicRoute.event(event.id)) {
                        MosaicSummaryCard(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct LivingKilnHero: View {
    let event: MosaicSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(event.communityName.uppercased())
                    .font(MosaicTheme.caption(.semibold))
                    .foregroundStyle(MosaicTheme.accentForeground)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 1)
                Text(event.name)
                    .font(MosaicTheme.display(30, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(heroDetail)
                    .font(.subheadline)
                    .foregroundStyle(MosaicTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LivingKilnMiniBoard(goal: event.goal, contributionCount: event.contributionCount)
                .padding(.top, 10)
                .padding(.bottom, 24)
            ViewThatFits(in: .horizontal) {
                HStack { progress; Spacer(); timing }
                VStack(alignment: .leading, spacing: 8) { progress; timing }
            }
            NavigationLink(value: MosaicRoute.event(event.id)) {
                Text(primaryAction).frame(maxWidth: .infinity)
            }
            .buttonStyle(MosaicPrimaryButtonStyle())
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [MosaicTheme.paper, MosaicTheme.claySurface.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay { RoundedRectangle(cornerRadius: 26).stroke(MosaicTheme.border) }
        .shadow(color: MosaicTheme.warmShadow, radius: 10, y: 5)
    }

    private var progress: some View {
        Label("\(event.contributionCount) of \(event.goal) tiles", systemImage: "square.grid.3x3.fill")
            .font(.subheadline.weight(.semibold))
    }

    private var timing: some View {
        Text(event.phase == .scheduled ? "Starts \(event.startAt.formatted(.relative(presentation: .numeric)))" : "Reveals \(event.revealAt.formatted(.relative(presentation: .numeric)))")
            .font(.subheadline)
            .foregroundStyle(MosaicTheme.muted)
    }

    private var primaryAction: String {
        switch event.phase {
        case .scheduled: "View upcoming Mosaic"
        case .active: "Choose an act"
        case .full: "See reveal countdown"
        case .revealed: "See what we made"
        case .deleted: "View Mosaic"
        }
    }

    private var heroDetail: String {
        switch event.phase {
        case .scheduled: "The kiln is ready. Kindness begins when this Mosaic starts."
        case .active: "Choose one small act and add an equal ceramic tile."
        case .full: "The kindness side is complete. Photos remain open until reveal."
        case .revealed: "The ceramic tiles have turned into shared artwork."
        case .deleted: "This Mosaic is no longer available."
        }
    }
}

private struct LivingKilnMiniBoard: View {
    let goal: Int
    let contributionCount: Int
    private var side: Int { Int(Double(goal).squareRoot()) }

    var body: some View {
        GeometryReader { proxy in
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: side > 7 ? 2 : 4), count: side),
                spacing: side > 7 ? 2 : 4
            ) {
                ForEach(0..<goal, id: \.self) { position in
                    CeramicTileFront(position: position, isContributed: position < contributionCount, compact: true)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.width)
        }
        .frame(width: 250, height: 250)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Living kiln board, \(contributionCount) of \(goal) tiles contributed")
    }
}

struct MosaicSummaryCard: View {
    let event: MosaicSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) { artworkPreview; details }
            } else {
                HStack(spacing: 14) { artworkPreview; details }
            }
        }
        .porcelainCard()
        .accessibilityElement(children: .combine)
    }

    private var artworkPreview: some View {
        ZStack {
            if event.phase == .revealed {
                Image(event.artwork.assetName)
                    .resizable().scaledToFill().frame(width: 88, height: 104).clipped()
            } else {
                MosaicTheme.claySurface
                SealedArtworkFace().frame(width: 52, height: 52)
            }
                if event.phase != .revealed {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                        ForEach(0..<9, id: \.self) { position in
                            CeramicTileFront(position: position, isContributed: position < min(event.contributionCount, 9), compact: true)
                        }
                    }
                    .padding(5)
                    .background(MosaicTheme.canvas.opacity(0.9))
                }
            }
            .frame(width: 88, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(MosaicTheme.border) }
        .accessibilityLabel(event.phase == .revealed ? event.artwork.altText : "Ceramic tile preview")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
                Text(event.name).font(MosaicTheme.display(22, weight: .semibold)).foregroundStyle(MosaicTheme.ink)
                Text(event.communityName).font(.subheadline).foregroundStyle(MosaicTheme.muted)
                ProgressView(value: Double(event.contributionCount), total: Double(event.goal)).tint(MosaicTheme.accentForeground)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text("\(event.contributionCount)/\(event.goal) tiles"); Spacer()
                        revealText
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(event.contributionCount)/\(event.goal) tiles"); revealText
                    }
                }
                .font(.caption.weight(.semibold)).foregroundStyle(MosaicTheme.muted)
        }
    }


    private var revealText: some View {
        Text(event.phase == .revealed ? "Revealed" : event.revealAt.formatted(.relative(presentation: .numeric)))
    }
}
