#!/usr/bin/env node

import { createCipheriv, createHash, randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const baseURL = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!baseURL || !serviceKey) {
  throw new Error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.");
}

const artworkFiles = {
  OnboardingWaterLilies: "Mosaic/Resources/Assets.xcassets/OnboardingWaterLilies.imageset/water-lilies.jpg",
  OnboardingParisStreet: "Mosaic/Resources/Assets.xcassets/OnboardingParisStreet.imageset/paris-street.jpg",
  OnboardingLaGrandeJatte: "Mosaic/Resources/Assets.xcassets/OnboardingLaGrandeJatte.imageset/la-grande-jatte.jpg",
  OnboardingBedroom: "Mosaic/Resources/Assets.xcassets/OnboardingBedroom.imageset/the-bedroom.jpg",
};

const headers = {
  apikey: serviceKey,
  Authorization: `Bearer ${serviceKey}`,
  "Content-Type": "application/json",
};

async function rpc(name, payload = {}) {
  const response = await fetch(`${baseURL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers,
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(`${name}: ${response.status} ${await response.text()}`);
  return response.json();
}

const pending = await rpc("v3_pending_artwork_packages");
for (const item of pending) {
  const relativePath = artworkFiles[item.assetName];
  if (!relativePath) throw new Error(`No reviewed local asset for ${item.assetName}`);
  const plaintext = await readFile(resolve(relativePath));
  const key = randomBytes(32);
  const nonce = randomBytes(12);
  const aad = Buffer.from(`mosaic-reveal:${item.mosaicID.toLowerCase()}`, "utf8");
  const cipher = createCipheriv("aes-256-gcm", key, nonce);
  cipher.setAAD(aad);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final(), cipher.getAuthTag()]);
  const path = `${item.mosaicID}/artwork.aesgcm`;
  const upload = await fetch(`${baseURL}/storage/v1/object/artwork-reveal-packages/${path}`, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/octet-stream",
      "x-upsert": "true",
    },
    body: ciphertext,
  });
  if (!upload.ok) throw new Error(`upload ${path}: ${upload.status} ${await upload.text()}`);
  await rpc("v3_register_artwork_package", {
    mosaicID: item.mosaicID,
    ciphertextPath: path,
    checksum: createHash("sha256").update(ciphertext).digest("hex"),
    encryptionKey: key.toString("base64"),
    nonce: nonce.toString("base64"),
  });
  process.stdout.write(`Prepared sealed artwork for ${item.mosaicID}\n`);
}

if (pending.length === 0) process.stdout.write("No pending artwork packages.\n");
