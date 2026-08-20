import { HttpError } from "./mosaic.ts";

export const KINDER_THEME_REVISION = 1;
export const KINDER_THEME_PALETTES = new Set([
  "signature",
  "soft",
  "kiln_night",
]);

export const KINDER_THEME_IDS = new Set(
  `
wildflower-meadow sunlit-daisies waterlily-pond fern-forest desert-bloom autumn-grove lavender-field rain-garden moonlit-botanicals community-garden
koi-circle butterfly-haven busy-bees songbird-canopy friendly-foxes whale-song playful-otters firefly-night turtle-tide puppy-parade
kinder-blockhouses open-door park-picnic street-fair shared-garden library-lights market-morning porch-stories bike-parade neighborhood-quilt
pottery-studio paper-cut-garden watercolor-wash stained-glass-sun crayon-sky origami-flock yarn-circle printmakers-table collage-party mosaic-workshop
vinyl-garden jazz-night drum-circle piano-bloom folk-dance disco-kindness lullaby-stars brass-parade string-quartet festival-rhythm
tea-table sunday-brunch fruit-market community-soup picnic-basket bakery-morning garden-feast cocoa-night lemonade-stand potluck-patchwork
mountain-trail beach-day camping-glow open-road balloon-voyage city-explorer island-postcards desert-stars forest-cabin river-journey
solar-garden cosmic-constellations moon-base rocket-club aurora-sky planet-parade microscope-meadow weather-station robot-workshop crystal-cave
soccer-circle basketball-court skate-park running-track tennis-garden swim-team bike-club playground-chalk game-night kite-festival
storybook-forest library-nook alphabet-garden science-fair maker-lab classroom-constellation poetry-pages history-map language-garden graduation-glow
sunrise-yoga quiet-tea ocean-breathing cozy-reading rainy-window gentle-clouds candlelight hammock-afternoon zen-garden moon-bath
birthday-confetti new-baby-sky wedding-garden anniversary-gold graduation-caps winter-lights spring-festival summer-solstice harvest-moon new-year-sparks
`.trim().split(/\s+/),
);

export function publishedTheme(input: {
  themeId: unknown;
  themePaletteId: unknown;
  themeSeed: unknown;
  themeRevision: unknown;
}) {
  if (
    typeof input.themeId !== "string" || !KINDER_THEME_IDS.has(input.themeId)
  ) {
    throw new HttpError(400, "themeId is not in the published Kinder catalog");
  }
  if (
    typeof input.themePaletteId !== "string" ||
    !KINDER_THEME_PALETTES.has(input.themePaletteId)
  ) {
    throw new HttpError(400, "themePaletteId is invalid");
  }
  if (input.themeRevision !== KINDER_THEME_REVISION) {
    throw new HttpError(
      409,
      "This artwork catalog revision is no longer published",
    );
  }
  const expectedSeed = stableThemeSeed(input.themeId);
  if (
    !Number.isSafeInteger(input.themeSeed) || input.themeSeed !== expectedSeed
  ) {
    throw new HttpError(400, "themeSeed does not match the published artwork");
  }
  return {
    theme_id: input.themeId,
    theme_palette_id: input.themePaletteId,
    theme_seed: expectedSeed,
    theme_revision: KINDER_THEME_REVISION,
  };
}

export function stableThemeSeed(id: string): number {
  let value = 17;
  for (const byte of new TextEncoder().encode(id)) {
    value = (Math.imul(value, 31) + byte) & 0x7fffffff;
  }
  return value;
}
