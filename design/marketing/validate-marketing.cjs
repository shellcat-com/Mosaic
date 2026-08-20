#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const sharp = require("sharp");

const root = __dirname;
const scenes = ["home", "mission", "privacy", "placement", "reveal"];
const exportFiles = [
  "01-together.png",
  "02-start-small.png",
  "03-private-by-design.png",
  "04-add-your-piece.png",
  "05-the-reveal.png"
];

async function validateImage(pathname, width, height, requireOpaqueRGB) {
  if (!fs.existsSync(pathname)) throw new Error(`Missing image: ${pathname}`);
  const metadata = await sharp(pathname).metadata();
  if (metadata.width !== width || metadata.height !== height) {
    throw new Error(`Invalid dimensions for ${pathname}: ${metadata.width}x${metadata.height}`);
  }
  if (requireOpaqueRGB && (metadata.hasAlpha || metadata.channels !== 3)) {
    throw new Error(`Expected opaque RGB image for ${pathname}: ${JSON.stringify(metadata)}`);
  }
  process.stdout.write(`✓ ${path.relative(process.cwd(), pathname)} — ${width}x${height}${requireOpaqueRGB ? ", RGB" : ""}\n`);
}

async function main() {
  for (const scene of scenes) {
    await validateImage(path.join(root, "captures", `${scene}.png`), 1320, 2868, false);
  }
  for (const filename of exportFiles) {
    await validateImage(path.join(root, "app-store", filename), 1320, 2868, true);
  }
  await validateImage(path.join(root, "repository", "mosaic-repository-hero.png"), 2400, 1200, true);
  await validateImage(path.join(root, "repository", "mosaic-app-store-gallery.png"), 2400, 1150, true);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
