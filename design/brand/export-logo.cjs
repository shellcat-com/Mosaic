#!/usr/bin/env node

const path = require("node:path");

// Allows the repository script to use Codex's bundled Sharp installation when
// NODE_PATH is provided, while still working with a normal local dependency.
require("node:module").Module._initPaths();
const sharp = require("sharp");

const brandDirectory = __dirname;
const source = path.join(brandDirectory, "mosaic-app-icon-master.png");
const output = path.resolve(
  brandDirectory,
  "../../Mosaic/Resources/Assets.xcassets/AppIcon.appiconset/MosaicAppIcon.png"
);

async function exportLogo() {
  await sharp(source, { density: 144 })
    .resize(1024, 1024, { fit: "fill" })
    .flatten({ background: "#fbf8f1" })
    .removeAlpha()
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toFile(output);

  const metadata = await sharp(output).metadata();
  if (
    metadata.width !== 1024 ||
    metadata.height !== 1024 ||
    metadata.channels !== 3 ||
    metadata.hasAlpha
  ) {
    throw new Error(`Invalid icon export: ${JSON.stringify(metadata)}`);
  }

  process.stdout.write(
    `Exported ${path.relative(process.cwd(), output)} (${metadata.width}x${metadata.height}, RGB, opaque)\n`
  );
}

exportLogo().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
