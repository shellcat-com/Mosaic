import { HttpError } from "./mosaic.ts";

const encoder = new TextEncoder();

function base64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function hex(bytes: Uint8Array): string {
  return Array.from(bytes).map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function sha256(bytes: Uint8Array): Promise<string> {
  const digestInput = Uint8Array.from(bytes);
  return hex(
    new Uint8Array(await crypto.subtle.digest("SHA-256", digestInput)),
  );
}

export type RevealPackage = {
  packageRevision: number;
  storagePath: string;
  key: string;
  nonce: string;
  aad: string;
  checksum: string;
  byteCount: number;
};

export async function recordRevealEvent(
  ctx: { supabaseAdmin: any },
  actorId: string,
  challengeId: string,
  name: string,
  properties: Record<string, unknown> = {},
): Promise<void> {
  const { error } = await ctx.supabaseAdmin.from("engagement_events").insert({
    actor_id: actorId,
    challenge_id: challengeId,
    client_event_id: crypto.randomUUID(),
    name,
    properties,
  });
  if (error) {
    console.warn("museum reveal telemetry insert failed", error.message);
  }
}

export async function buildRevealPackage(
  ctx: { supabaseAdmin: any },
  challengeId: string,
  artworkId: string,
  catalogRevision: number,
  packageRevision: number,
): Promise<RevealPackage> {
  const { data: asset, error: assetError } = await ctx.supabaseAdmin.rpc(
    "internal_get_artwork_asset",
    { target_artwork_id: artworkId },
  );
  if (assetError) throw new HttpError(500, assetError.message);
  if (!asset?.displayPath) {
    throw new HttpError(409, "Artwork source has not finished importing");
  }

  const { data: source, error: downloadError } = await ctx.supabaseAdmin.storage
    .from("museum-artwork-sources").download(asset.displayPath);
  if (downloadError || !source) {
    throw new HttpError(409, "Artwork display source is unavailable");
  }

  const plaintext = new Uint8Array(await source.arrayBuffer());
  const keyBytes = crypto.getRandomValues(new Uint8Array(32));
  const nonceBytes = crypto.getRandomValues(new Uint8Array(12));
  const aad =
    `mosaic-reveal:${challengeId}:catalog:${catalogRevision}:package:${packageRevision}`;
  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );
  const ciphertext = new Uint8Array(
    await crypto.subtle.encrypt(
      {
        name: "AES-GCM",
        iv: nonceBytes,
        additionalData: encoder.encode(aad),
        tagLength: 128,
      },
      key,
      plaintext,
    ),
  );

  const storagePath = `${challengeId}/${packageRevision}.aesgcm`;
  const { error: uploadError } = await ctx.supabaseAdmin.storage
    .from("museum-reveal-packages").upload(storagePath, ciphertext, {
      contentType: "application/octet-stream",
      cacheControl: "31536000",
      upsert: true,
    });
  if (uploadError) throw new HttpError(500, uploadError.message);

  return {
    packageRevision,
    storagePath,
    key: base64(keyBytes),
    nonce: base64(nonceBytes),
    aad,
    checksum: await sha256(ciphertext),
    byteCount: ciphertext.byteLength,
  };
}
