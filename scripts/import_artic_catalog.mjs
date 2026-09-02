#!/usr/bin/env node

import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const manifestPath = path.resolve(
  scriptDirectory,
  "../supabase/catalog/artic-museum-artworks.v1.json",
);
const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
const records = manifest.records ?? [];
const expectedRecordCount = manifest.expectedRecordCount;
const collections = new Set([
  "nature",
  "animals",
  "community",
  "making",
  "music",
  "gathering",
  "adventure",
  "discovery",
  "play",
  "learning",
  "calm",
  "milestones",
]);

function invariant(condition, message) {
  if (!condition) throw new Error(message);
}

function sha256(data) {
  return createHash("sha256").update(data).digest("hex");
}

function validateManifest() {
  invariant(
    Number.isInteger(expectedRecordCount) && expectedRecordCount > 0,
    "Manifest expectedRecordCount must be a positive integer",
  );
  invariant(
    records.length === expectedRecordCount,
    `Catalog must contain exactly ${expectedRecordCount} works; found ${records.length}`,
  );
  invariant(
    new Set(records.map((record) => record.id)).size === expectedRecordCount,
    "Catalog UUIDs must be unique",
  );
  invariant(
    new Set(records.map((record) => record.museumArtworkId)).size === expectedRecordCount,
    "Museum artwork IDs must be unique",
  );
  invariant(
    new Set(records.map((record) => record.imageId)).size === expectedRecordCount,
    "Image IDs must be unique",
  );

  const coveredCollections = new Set();
  for (const record of records) {
    invariant(record.isPublicDomain === true, `${record.title} is not marked public domain`);
    invariant(record.imageId, `${record.title} is missing imageId`);
    invariant(record.altText?.trim(), `${record.title} is missing alt text`);
    invariant(
      record.sourceURL === `https://www.artic.edu/artworks/${record.museumArtworkId}`,
      `${record.title} has an invalid source URL`,
    );
    invariant(collections.has(record.collection), `${record.title} has an unknown collection`);
    invariant(record.dominantColors?.length >= 3, `${record.title} needs at least three colors`);
    invariant(/^[0-9a-f]{64}$/.test(record.manifestChecksum), `${record.title} has an invalid checksum`);

    const crop = record.crop;
    invariant(crop.x >= 0 && crop.y >= 0, `${record.title} crop starts outside the image`);
    invariant(crop.width > 0 && crop.height > 0, `${record.title} crop is empty`);
    invariant(crop.x + crop.width <= 1.000001, `${record.title} crop exceeds image width`);
    invariant(crop.y + crop.height <= 1.000001, `${record.title} crop exceeds image height`);
    const squareDelta = Math.abs(
      crop.width * record.sourceWidth - crop.height * record.sourceHeight,
    );
    invariant(squareDelta < 2, `${record.title} crop is not square in source pixels`);
    coveredCollections.add(record.collection);
  }
  invariant(coveredCollections.size === collections.size, "Every interest collection needs coverage");
}

validateManifest();

if (!process.argv.includes("--import")) {
  console.log(`Validated ${records.length} reviewed Art Institute works across ${collections.size} collections.`);
  process.exit(0);
}

const supabaseURL = process.env.SUPABASE_URL?.replace(/\/$/, "");
const secretKey = process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;
invariant(supabaseURL, "SUPABASE_URL is required for --import");
invariant(secretKey, "SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY is required for --import");

const force = process.argv.includes("--force");
const commonHeaders = {
  apikey: secretKey,
  Authorization: `Bearer ${secretKey}`,
};

async function request(url, options = {}) {
  const response = await fetch(url, options);
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`${response.status} ${response.statusText}: ${detail}`);
  }
  return response;
}

async function rest(pathname, body, extraHeaders = {}) {
  return request(`${supabaseURL}/rest/v1/${pathname}`, {
    method: "POST",
    headers: {
      ...commonHeaders,
      "Content-Type": "application/json",
      ...extraHeaders,
    },
    body: JSON.stringify(body),
  });
}

function catalogRow(record) {
  return {
    id: record.id,
    slug: record.slug,
    museum_artwork_id: record.museumArtworkId,
    image_id: record.imageId,
    title: record.title,
    artist_display: record.artistDisplay,
    date_display: record.dateDisplay,
    source_url: record.sourceURL,
    alt_text: record.altText,
    collection: record.collection,
    dominant_colors: record.dominantColors,
    source_width: record.sourceWidth,
    source_height: record.sourceHeight,
    crop_x: record.crop.x,
    crop_y: record.crop.y,
    crop_width: record.crop.width,
    crop_height: record.crop.height,
    is_public_domain: true,
    license_label: record.licenseLabel,
    catalog_revision: record.catalogRevision,
    manifest_checksum: record.manifestChecksum,
    content_reviewed_at: record.contentReviewedAt,
    crop_reviewed_at: record.cropReviewedAt,
    active: true,
  };
}

async function existingAsset(record) {
  const response = await rest("rpc/internal_get_artwork_asset", {
    target_artwork_id: record.id,
  });
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

async function uploadObject(objectPath, data) {
  await request(
    `${supabaseURL}/storage/v1/object/museum-artwork-sources/${objectPath}`,
    {
      method: "POST",
      headers: {
        ...commonHeaders,
        "Content-Type": "image/jpeg",
        "x-upsert": "true",
        "cache-control": "31536000, immutable",
      },
      body: data,
    },
  );
}

const waitForMuseumRate = () => new Promise((resolve) => setTimeout(resolve, 1_100));

for (const [index, record] of records.entries()) {
  await rest(
    "artwork_catalog?on_conflict=museum_artwork_id",
    [catalogRow(record)],
    { Prefer: "resolution=merge-duplicates,return=minimal" },
  );

  const existing = await existingAsset(record);
  if (!force && existing?.displayChecksum && existing?.exportChecksum) {
    console.log(`[${index + 1}/${records.length}] ${record.title} already imported`);
    continue;
  }

  const displayURL = `${manifest.iiifBaseURL}/${record.imageId}/full/843,/0/default.jpg`;
  const exportURL = `${manifest.iiifBaseURL}/${record.imageId}/full/1686,/0/default.jpg`;
  const displayData = Buffer.from(await (await request(displayURL)).arrayBuffer());
  await waitForMuseumRate();
  const exportData = Buffer.from(await (await request(exportURL)).arrayBuffer());
  await waitForMuseumRate();

  const displayPath = `${record.museumArtworkId}/843.jpg`;
  const exportPath = `${record.museumArtworkId}/1686.jpg`;
  await uploadObject(displayPath, displayData);
  await uploadObject(exportPath, exportData);
  await rest("rpc/internal_record_artwork_asset", {
    target_artwork_id: record.id,
    target_display_path: displayPath,
    target_display_checksum: sha256(displayData),
    target_display_byte_count: displayData.byteLength,
    target_export_path: exportPath,
    target_export_checksum: sha256(exportData),
    target_export_byte_count: exportData.byteLength,
    target_provenance: {
      museum: manifest.museum,
      api: `https://api.artic.edu/api/v1/artworks/${record.museumArtworkId}`,
      displayIIIF: displayURL,
      exportIIIF: exportURL,
      manifestChecksum: record.manifestChecksum,
      importer: "scripts/import_artic_catalog.mjs@1",
      importedAt: new Date().toISOString(),
    },
  });
  console.log(`[${index + 1}/${records.length}] imported ${record.title}`);
}

console.log("Museum artwork import complete.");
