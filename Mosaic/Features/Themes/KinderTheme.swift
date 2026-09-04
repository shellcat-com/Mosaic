import Foundation

enum KinderThemeCollection: String, CaseIterable, Codable, Identifiable, Sendable {
    case nature
    case animals
    case community
    case making
    case music
    case gathering
    case adventure
    case discovery
    case play
    case learning
    case calm
    case milestones

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nature: "Nature & Gardens"
        case .animals: "Animals & Wildlife"
        case .community: "Neighborhood & Community"
        case .making: "Arts & Making"
        case .music: "Music & Dance"
        case .gathering: "Food & Gathering"
        case .adventure: "Adventure & Travel"
        case .discovery: "Space & Discovery"
        case .play: "Sports & Play"
        case .learning: "Books & Learning"
        case .calm: "Calm & Care"
        case .milestones: "Milestones & Seasons"
        }
    }

    var symbol: String {
        switch self {
        case .nature: "camera.macro"
        case .animals: "pawprint.fill"
        case .community: "house.and.flag.fill"
        case .making: "paintpalette.fill"
        case .music: "music.note"
        case .gathering: "fork.knife"
        case .adventure: "map.fill"
        case .discovery: "sparkles"
        case .play: "figure.play"
        case .learning: "books.vertical.fill"
        case .calm: "heart.circle.fill"
        case .milestones: "party.popper.fill"
        }
    }
}

enum KinderThemePaletteID: String, CaseIterable, Codable, Identifiable, Sendable {
    case signature
    case soft
    case kilnNight = "kiln_night"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signature: "Signature"
        case .soft: "Soft"
        case .kilnNight: "Kiln Night"
        }
    }
}

enum KinderArtworkPhase: String, Codable, Sendable {
    case thumbnail
    case invitation
    case sealed
    case active
    case reveal
    case recap
    case poster
}

enum KinderComposition: String, Codable, CaseIterable, Sendable {
    case bouquet, orbit, landscape, quilt, arch, cascade, stillLife, constellation, procession, vignette
}

enum KinderMaterial: String, Codable, CaseIterable, Sendable {
    case glazedClay, gouachePaper, carvedSlip, stitchedFabric, pressedPetal, chalkWash, inkedPorcelain, mosaicGlass
}

enum KinderRevealMotion: String, Codable, CaseIterable, Sendable {
    case bloom, ripple, rise, stitch, scatter, glow, unfold, drift, parade, twinkle
}

struct KinderTheme: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let collection: KinderThemeCollection
    let tagline: String
    let accessibilityDescription: String
    let tags: [String]
    let heroSymbol: String
    let accentSymbol: String
    let composition: KinderComposition
    let material: KinderMaterial
    let revealMotion: KinderRevealMotion
    let seed: Int
    let signatureHex: [UInt32]
}

struct ThemeSelection: Hashable, Codable, Sendable {
    var themeID: String
    var paletteID: KinderThemePaletteID
    var seed: Int
    var revision: Int

    static let fallback = ThemeSelection(
        themeID: "neighborhood-quilt",
        paletteID: .signature,
        seed: 1_636_670_815,
        revision: 1
    )

    var theme: KinderTheme {
        KinderThemeCatalog.theme(id: themeID)
    }
}

struct ChallengeDraft: Hashable, Codable, Sendable {
    var interests: Set<KinderThemeCollection> = []
    var selection: ThemeSelection = .fallback
    var usesMuseumArtwork = true
    var artworkID: UUID?
    var boardSide = 5
    var name = ""
    var groupName = ""
    var purpose = ""
    var goal = 25
    var startDate = Date.now
    var revealDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    var experienceVersion: MosaicExperienceVersion = .kindnessRoll
    var filmLookID: FilmLookID = .sunwashed

    var isReadyToCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!usesMuseumArtwork || (
                artworkID != nil
                    && (3...10).contains(boardSide)
                    && goal == boardSide * boardSide
            ))
            && revealDate > startDate
    }
}

enum KinderThemeCatalog {
    static let revision = 1
    static let all: [KinderTheme] = buildCatalog()
    static let fallback = theme(id: ThemeSelection.fallback.themeID)

    static func theme(id: String) -> KinderTheme {
        all.first(where: { $0.id == id }) ?? all.first(where: { $0.id == "neighborhood-quilt" })!
    }

    static func recommendations(for interests: Set<KinderThemeCollection>) -> [KinderTheme] {
        guard !interests.isEmpty else { return all }
        return all.filter { interests.contains($0.collection) }
            + all.filter { !interests.contains($0.collection) }
    }

    private struct Seed {
        let name: String
        let symbol: String
        let accent: String
        let composition: KinderComposition
        let material: KinderMaterial
        let motion: KinderRevealMotion
        let tagline: String
    }

    private static func s(
        _ name: String,
        _ symbol: String,
        _ accent: String,
        _ composition: KinderComposition,
        _ material: KinderMaterial,
        _ motion: KinderRevealMotion,
        _ tagline: String
    ) -> Seed {
        Seed(name: name, symbol: symbol, accent: accent, composition: composition, material: material, motion: motion, tagline: tagline)
    }

    private static func buildCatalog() -> [KinderTheme] {
        var output: [KinderTheme] = []
        append(.nature, palette: [0xF6C453, 0x7D9A83, 0xE8A5B5], seeds: nature, to: &output)
        append(.animals, palette: [0xEE9C62, 0x6FA9B8, 0xE7C96D], seeds: animals, to: &output)
        append(.community, palette: [0xF17855, 0x7987C9, 0xA9B892], seeds: community, to: &output)
        append(.making, palette: [0xE58CA8, 0x6F8FD4, 0xF3C45E], seeds: making, to: &output)
        append(.music, palette: [0x9D79C8, 0xEF7659, 0x63A6A1], seeds: music, to: &output)
        append(.gathering, palette: [0xE99258, 0x9DAA70, 0xD8878F], seeds: gathering, to: &output)
        append(.adventure, palette: [0xE9A84D, 0x5F9FB3, 0x8CA878], seeds: adventure, to: &output)
        append(.discovery, palette: [0x6B67C7, 0xE787AF, 0xE7C95E], seeds: discovery, to: &output)
        append(.play, palette: [0xE96F4C, 0x5B91CE, 0xE2C75C], seeds: play, to: &output)
        append(.learning, palette: [0x7A74C9, 0xD88472, 0x84A77A], seeds: learning, to: &output)
        append(.calm, palette: [0x7AA7A1, 0xB79BCB, 0xE9B18D], seeds: calm, to: &output)
        append(.milestones, palette: [0xE87975, 0xD6A937, 0x7896C7], seeds: milestones, to: &output)
        return output
    }

    private static func append(
        _ collection: KinderThemeCollection,
        palette: [UInt32],
        seeds: [Seed],
        to output: inout [KinderTheme]
    ) {
        for (index, seed) in seeds.enumerated() {
            let id = slug(seed.name)
            let offset = index % palette.count
            let rotated = Array(palette[offset...]) + Array(palette[..<offset])
            output.append(KinderTheme(
                id: id,
                name: seed.name,
                collection: collection,
                tagline: seed.tagline,
                accessibilityDescription: "A hand-painted ceramic scene called \(seed.name), from the \(collection.title) collection. \(seed.tagline)",
                tags: [collection.rawValue, collection.title.lowercased(), seed.name.lowercased(), seed.tagline.lowercased()],
                heroSymbol: seed.symbol,
                accentSymbol: seed.accent,
                composition: seed.composition,
                material: seed.material,
                revealMotion: seed.motion,
                seed: stableSeed(id),
                signatureHex: rotated
            ))
        }
    }

    private static func slug(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "&", with: "and")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "-")
    }

    private static func stableSeed(_ text: String) -> Int {
        text.utf8.reduce(17) { (($0 &* 31) &+ Int($1)) & 0x7fff_ffff }
    }

    private static let nature: [Seed] = [
        s("Wildflower Meadow", "camera.macro", "leaf.fill", .bouquet, .pressedPetal, .bloom, "Loose meadow flowers gather like small acts of care."),
        s("Sunlit Daisies", "sun.max.fill", "camera.macro", .orbit, .glazedClay, .glow, "Daisies turn toward a warm handmade sun."),
        s("Waterlily Pond", "drop.fill", "circle.fill", .landscape, .gouachePaper, .ripple, "Soft lily pads float across painted water."),
        s("Fern Forest", "leaf.fill", "tree.fill", .cascade, .carvedSlip, .rise, "Layered ferns unfold beneath a quiet canopy."),
        s("Desert Bloom", "sun.horizon.fill", "camera.macro", .vignette, .chalkWash, .bloom, "A resilient bloom opens in warm desert clay."),
        s("Autumn Grove", "tree.fill", "leaf.fill", .procession, .inkedPorcelain, .drift, "Amber leaves wander through a shared grove."),
        s("Lavender Field", "camera.macro", "wind", .landscape, .gouachePaper, .drift, "Lavender rows sway in a violet paper breeze."),
        s("Rain Garden", "cloud.rain.fill", "leaf.fill", .cascade, .glazedClay, .ripple, "Rain beads collect around bright new leaves."),
        s("Moonlit Botanicals", "moon.stars.fill", "leaf.fill", .arch, .inkedPorcelain, .twinkle, "Night flowers glow against deep kiln blue."),
        s("Community Garden", "carrot.fill", "figure.2", .quilt, .stitchedFabric, .stitch, "Many tended patches become one generous garden.")
    ]

    private static let animals: [Seed] = [
        s("Koi Circle", "fish.fill", "water.waves", .orbit, .glazedClay, .ripple, "Painted koi travel in a calm circle of care."),
        s("Butterfly Haven", "butterfly.fill", "camera.macro", .bouquet, .pressedPetal, .bloom, "Butterflies settle among soft paper blossoms."),
        s("Busy Bees", "ant.fill", "hexagon.fill", .quilt, .carvedSlip, .scatter, "Tiny makers build a bright honeycomb together."),
        s("Songbird Canopy", "bird.fill", "music.note", .arch, .gouachePaper, .rise, "Small birds trade songs beneath leafy branches."),
        s("Friendly Foxes", "pawprint.fill", "leaf.fill", .vignette, .inkedPorcelain, .parade, "Curious woodland friends meet beside the path."),
        s("Whale Song", "water.waves", "music.note", .landscape, .chalkWash, .ripple, "A gentle whale song travels through blue glaze."),
        s("Playful Otters", "figure.pool.swim", "drop.fill", .procession, .glazedClay, .parade, "Otters drift hand in hand through painted water."),
        s("Firefly Night", "sparkles", "moon.fill", .constellation, .inkedPorcelain, .twinkle, "Fireflies stitch warm light into the evening."),
        s("Turtle Tide", "tortoise.fill", "water.waves", .cascade, .carvedSlip, .rise, "Patient turtles follow the turning tide."),
        s("Puppy Parade", "dog.fill", "pawprint.fill", .procession, .stitchedFabric, .parade, "Playful pups make every small step a celebration.")
    ]

    private static let community: [Seed] = [
        s("Kinder Blockhouses", "house.fill", "heart.fill", .quilt, .carvedSlip, .rise, "Wonky little homes make one welcoming block."),
        s("Open Door", "door.left.hand.open", "sparkles", .arch, .inkedPorcelain, .unfold, "A glowing doorway invites neighbors inside."),
        s("Park Picnic", "figure.2", "basket.fill", .landscape, .gouachePaper, .scatter, "Blankets, trees, and shared time fill the park."),
        s("Street Fair", "storefront.fill", "party.popper.fill", .procession, .stitchedFabric, .parade, "Handmade stalls bring a friendly street to life."),
        s("Shared Garden", "leaf.fill", "hands.sparkles.fill", .bouquet, .pressedPetal, .bloom, "Many hands tend one abundant garden."),
        s("Library Lights", "books.vertical.fill", "lightbulb.fill", .arch, .inkedPorcelain, .glow, "Warm windows and stories light the neighborhood."),
        s("Market Morning", "basket.fill", "sun.max.fill", .stillLife, .gouachePaper, .rise, "A colorful morning market opens for everyone."),
        s("Porch Stories", "text.bubble.fill", "house.fill", .vignette, .chalkWash, .unfold, "Stories gather on a porch at the end of day."),
        s("Bike Parade", "bicycle", "flag.fill", .procession, .glazedClay, .parade, "Bright wheels and handmade flags roll together."),
        s("Neighborhood Quilt", "square.grid.3x3.fill", "heart.fill", .quilt, .stitchedFabric, .stitch, "Different patches form one warm place to belong.")
    ]

    private static let making: [Seed] = [
        s("Pottery Studio", "paintbrush.fill", "circle.fill", .stillLife, .glazedClay, .rise, "Hand-thrown vessels wait beside a painted brush."),
        s("Paper Cut Garden", "scissors", "camera.macro", .bouquet, .gouachePaper, .unfold, "Cut-paper leaves bloom in layered color."),
        s("Watercolor Wash", "paintpalette.fill", "drop.fill", .cascade, .gouachePaper, .ripple, "Loose pigments meet and soften on warm paper."),
        s("Stained Glass Sun", "sun.max.fill", "diamond.fill", .orbit, .mosaicGlass, .glow, "Colored glass pieces hold a radiant sun."),
        s("Crayon Sky", "pencil.and.scribble", "cloud.fill", .landscape, .chalkWash, .scatter, "Joyful crayon marks build a wide open sky."),
        s("Origami Flock", "bird.fill", "triangle.fill", .procession, .gouachePaper, .drift, "Folded paper birds travel across the page."),
        s("Yarn Circle", "circle.grid.cross.fill", "heart.fill", .orbit, .stitchedFabric, .stitch, "Loose threads loop into one caring circle."),
        s("Printmaker’s Table", "printer.fill", "leaf.fill", .stillLife, .inkedPorcelain, .rise, "Carved stamps leave lively imperfect marks."),
        s("Collage Party", "photo.on.rectangle.angled", "sparkles", .constellation, .gouachePaper, .scatter, "Torn paper pieces become a cheerful whole."),
        s("Mosaic Workshop", "square.grid.3x3.fill", "hammer.fill", .quilt, .mosaicGlass, .stitch, "Small ceramic pieces assemble into shared color.")
    ]

    private static let music: [Seed] = [
        s("Vinyl Garden", "record.circle.fill", "camera.macro", .orbit, .inkedPorcelain, .ripple, "A spinning record grows a painted garden."),
        s("Jazz Night", "music.note", "moon.stars.fill", .vignette, .glazedClay, .glow, "Indigo notes curl through a warm night room."),
        s("Drum Circle", "circle.circle.fill", "hand.raised.fill", .orbit, .carvedSlip, .ripple, "Hand drums share one friendly rhythm."),
        s("Piano Bloom", "pianokeys", "camera.macro", .cascade, .inkedPorcelain, .bloom, "Painted blossoms rise between ivory keys."),
        s("Folk Dance", "figure.dance", "leaf.fill", .procession, .stitchedFabric, .parade, "Dancers join hands across a patterned floor."),
        s("Disco Kindness", "sparkles", "circle.hexagongrid.fill", .orbit, .mosaicGlass, .twinkle, "A mirrored ceramic globe scatters joyful light."),
        s("Lullaby Stars", "moon.stars.fill", "music.note", .constellation, .gouachePaper, .twinkle, "Quiet notes tuck stars into the evening."),
        s("Brass Parade", "music.note.list", "flag.fill", .procession, .glazedClay, .parade, "Golden instruments march through painted confetti."),
        s("String Quartet", "music.quarternote.3", "heart.fill", .quilt, .carvedSlip, .stitch, "Four carved melodies settle into harmony."),
        s("Festival Rhythm", "waveform", "party.popper.fill", .cascade, .chalkWash, .rise, "Colorful beats rise through a handmade festival.")
    ]

    private static let gathering: [Seed] = [
        s("Tea Table", "cup.and.saucer.fill", "leaf.fill", .stillLife, .inkedPorcelain, .rise, "Mismatched cups make space for conversation."),
        s("Sunday Brunch", "fork.knife", "sun.max.fill", .stillLife, .gouachePaper, .glow, "A sunny table gathers generous little plates."),
        s("Fruit Market", "basket.fill", "leaf.fill", .quilt, .pressedPetal, .scatter, "Hand-painted fruit fills a woven market basket."),
        s("Community Soup", "takeoutbag.and.cup.and.straw.fill", "heart.fill", .vignette, .glazedClay, .rise, "A warm shared pot feeds the whole table."),
        s("Picnic Basket", "basket.fill", "camera.macro", .landscape, .stitchedFabric, .unfold, "A checked blanket opens beneath summer flowers."),
        s("Bakery Morning", "birthday.cake.fill", "sun.horizon.fill", .procession, .chalkWash, .glow, "Fresh loaves and warm windows greet the morning."),
        s("Garden Feast", "carrot.fill", "leaf.fill", .bouquet, .pressedPetal, .bloom, "Garden color spills across a welcoming table."),
        s("Cocoa Night", "mug.fill", "moon.stars.fill", .vignette, .glazedClay, .glow, "A speckled mug warms a quiet winter night."),
        s("Lemonade Stand", "drop.fill", "sun.max.fill", .arch, .gouachePaper, .scatter, "A bright little stand turns care into refreshment."),
        s("Potluck Patchwork", "rectangle.grid.2x2.fill", "fork.knife", .quilt, .stitchedFabric, .stitch, "Every dish adds a new patch to the table.")
    ]

    private static let adventure: [Seed] = [
        s("Mountain Trail", "mountain.2.fill", "figure.hiking", .landscape, .carvedSlip, .rise, "A winding path climbs through layered clay peaks."),
        s("Beach Day", "beach.umbrella.fill", "water.waves", .landscape, .chalkWash, .ripple, "Painted waves meet a joyful striped umbrella."),
        s("Camping Glow", "tent.fill", "flame.fill", .vignette, .inkedPorcelain, .glow, "A small campfire glows beneath tall trees."),
        s("Open Road", "car.fill", "sun.horizon.fill", .procession, .gouachePaper, .drift, "A paper road curls toward the bright horizon."),
        s("Balloon Voyage", "balloon.2.fill", "cloud.fill", .cascade, .stitchedFabric, .rise, "Patchwork balloons lift into a soft sky."),
        s("City Explorer", "building.2.fill", "map.fill", .arch, .inkedPorcelain, .unfold, "Hand-drawn streets reveal friendly city corners."),
        s("Island Postcards", "mail.stack.fill", "water.waves", .quilt, .gouachePaper, .scatter, "Torn postcard scenes remember an island journey."),
        s("Desert Stars", "sun.horizon.fill", "sparkles", .constellation, .chalkWash, .twinkle, "Night stars gather over quiet painted dunes."),
        s("Forest Cabin", "house.lodge.fill", "tree.fill", .vignette, .carvedSlip, .glow, "A crooked little cabin waits among the pines."),
        s("River Journey", "water.waves", "leaf.fill", .cascade, .glazedClay, .ripple, "A blue glaze river carries tiny boats onward.")
    ]

    private static let discovery: [Seed] = [
        s("Solar Garden", "sun.max.fill", "leaf.fill", .orbit, .mosaicGlass, .glow, "Leaves and planets grow around a ceramic sun."),
        s("Cosmic Constellations", "sparkles", "point.3.connected.trianglepath.dotted", .constellation, .inkedPorcelain, .twinkle, "Hand-drawn stars connect into caring shapes."),
        s("Moon Base", "moon.fill", "house.fill", .landscape, .carvedSlip, .rise, "A tiny clay outpost rests on a quiet moon."),
        s("Rocket Club", "rocket.fill", "person.3.fill", .procession, .glazedClay, .rise, "A handmade rocket lifts a curious crew."),
        s("Aurora Sky", "cloud.rainbow.half", "sparkles", .cascade, .gouachePaper, .drift, "Loose painted light moves through the polar night."),
        s("Planet Parade", "globe.americas.fill", "circle.fill", .procession, .mosaicGlass, .parade, "Colorful planets roll through a playful cosmos."),
        s("Microscope Meadow", "microscope", "camera.macro", .bouquet, .inkedPorcelain, .bloom, "Tiny discoveries bloom beneath the lens."),
        s("Weather Station", "cloud.sun.rain.fill", "wind", .quilt, .chalkWash, .scatter, "Sun, rain, and wind share one curious forecast."),
        s("Robot Workshop", "cpu.fill", "wrench.and.screwdriver.fill", .stillLife, .carvedSlip, .stitch, "Friendly parts assemble on a maker’s bench."),
        s("Crystal Cave", "diamond.fill", "sparkles", .arch, .mosaicGlass, .glow, "Faceted color shines inside a deep clay cave.")
    ]

    private static let play: [Seed] = [
        s("Soccer Circle", "soccerball", "figure.2", .orbit, .stitchedFabric, .parade, "A stitched ball brings every player together."),
        s("Basketball Court", "basketball.fill", "square.grid.3x3.fill", .quilt, .carvedSlip, .rise, "Painted court lines frame a bouncing orange sun."),
        s("Skate Park", "figure.skating", "scribble.variable", .cascade, .chalkWash, .drift, "Curved ramps and loose lines carry playful motion."),
        s("Running Track", "figure.run", "flag.checkered", .procession, .inkedPorcelain, .parade, "Runners share a winding terracotta track."),
        s("Tennis Garden", "tennisball.fill", "leaf.fill", .orbit, .pressedPetal, .bloom, "A bright ball travels through leafy court lines."),
        s("Swim Team", "figure.pool.swim", "water.waves", .landscape, .glazedClay, .ripple, "Blue lanes ripple with equal shared effort."),
        s("Bike Club", "bicycle", "person.3.fill", .procession, .stitchedFabric, .parade, "Colorful wheels follow one another through town."),
        s("Playground Chalk", "figure.play", "pencil.and.scribble", .constellation, .chalkWash, .scatter, "Hand-drawn games cover a sunny playground."),
        s("Game Night", "dice.fill", "heart.fill", .stillLife, .inkedPorcelain, .scatter, "Wonky game pieces gather around the table."),
        s("Kite Festival", "kite.fill", "wind", .cascade, .gouachePaper, .rise, "Paper kites lift together on a painted breeze.")
    ]

    private static let learning: [Seed] = [
        s("Storybook Forest", "book.closed.fill", "tree.fill", .arch, .gouachePaper, .unfold, "An open book grows into a gentle forest."),
        s("Library Nook", "books.vertical.fill", "chair.lounge.fill", .vignette, .inkedPorcelain, .glow, "Crooked shelves surround a soft reading chair."),
        s("Alphabet Garden", "textformat.abc", "camera.macro", .bouquet, .pressedPetal, .bloom, "Letters sprout among playful painted flowers."),
        s("Science Fair", "atom", "lightbulb.fill", .quilt, .carvedSlip, .twinkle, "Curious handmade experiments fill the display."),
        s("Maker Lab", "hammer.fill", "gearshape.fill", .stillLife, .inkedPorcelain, .stitch, "Tools and bright ideas share one workbench."),
        s("Classroom Constellation", "sparkles.rectangle.stack", "person.3.fill", .constellation, .chalkWash, .twinkle, "Every learner becomes a point of light."),
        s("Poetry Pages", "text.book.closed.fill", "quote.bubble.fill", .cascade, .gouachePaper, .unfold, "Loose words drift across handmade paper."),
        s("History Map", "map.fill", "clock.fill", .quilt, .inkedPorcelain, .unfold, "Layered paths connect stories across time."),
        s("Language Garden", "character.book.closed.fill", "leaf.fill", .bouquet, .pressedPetal, .bloom, "Many languages flower in the same garden."),
        s("Graduation Glow", "graduationcap.fill", "sparkles", .procession, .mosaicGlass, .rise, "Caps lift through warm light and painted stars.")
    ]

    private static let calm: [Seed] = [
        s("Sunrise Yoga", "figure.mind.and.body", "sun.horizon.fill", .landscape, .chalkWash, .rise, "A quiet figure greets the softly painted sun."),
        s("Quiet Tea", "cup.and.saucer.fill", "leaf.fill", .stillLife, .inkedPorcelain, .rise, "Steam curls above a small speckled cup."),
        s("Ocean Breathing", "wind", "water.waves", .landscape, .glazedClay, .ripple, "Slow waves move with one steady breath."),
        s("Cozy Reading", "book.closed.fill", "flame.fill", .vignette, .stitchedFabric, .glow, "A warm book rests beneath a patchwork blanket."),
        s("Rainy Window", "cloud.rain.fill", "window.vertical.closed", .quilt, .gouachePaper, .ripple, "Painted raindrops soften the view outside."),
        s("Gentle Clouds", "cloud.fill", "wind", .cascade, .chalkWash, .drift, "Soft imperfect clouds wander through open space."),
        s("Candlelight", "flame.fill", "sparkles", .vignette, .glazedClay, .glow, "One small flame warms a deep kiln-night room."),
        s("Hammock Afternoon", "bed.double.fill", "leaf.fill", .landscape, .stitchedFabric, .drift, "A woven rest hangs between two painted trees."),
        s("Zen Garden", "circle.grid.cross.fill", "leaf.fill", .orbit, .carvedSlip, .ripple, "Carved lines circle a few quiet stones."),
        s("Moon Bath", "moon.fill", "drop.fill", .arch, .mosaicGlass, .glow, "Moonlight pools in a calm porcelain basin.")
    ]

    private static let milestones: [Seed] = [
        s("Birthday Confetti", "party.popper.fill", "birthday.cake.fill", .constellation, .gouachePaper, .scatter, "Torn-paper confetti surrounds a joyful little cake."),
        s("New Baby Sky", "stroller.fill", "cloud.fill", .cascade, .stitchedFabric, .drift, "Patchwork clouds welcome a brand-new beginning."),
        s("Wedding Garden", "heart.circle.fill", "camera.macro", .arch, .pressedPetal, .bloom, "Hand-painted flowers form a generous garden arch."),
        s("Anniversary Gold", "circle.circle.fill", "heart.fill", .orbit, .mosaicGlass, .glow, "Two imperfect golden circles continue together."),
        s("Graduation Caps", "graduationcap.fill", "sparkles", .procession, .inkedPorcelain, .rise, "Painted caps rise into a hopeful sky."),
        s("Winter Lights", "snowflake", "lightbulb.fill", .constellation, .glazedClay, .twinkle, "Warm bulbs glow between carved snowflakes."),
        s("Spring Festival", "camera.macro", "party.popper.fill", .bouquet, .gouachePaper, .bloom, "Flowers and paper ribbons welcome the season."),
        s("Summer Solstice", "sun.max.fill", "leaf.fill", .orbit, .pressedPetal, .glow, "A bright ceramic sun crowns the longest day."),
        s("Harvest Moon", "moon.fill", "leaf.fill", .landscape, .carvedSlip, .rise, "A golden moon rests above gathered fields."),
        s("New Year Sparks", "fireworks", "sparkles", .cascade, .mosaicGlass, .twinkle, "Hand-cut sparks open across the midnight glaze.")
    ]
}
