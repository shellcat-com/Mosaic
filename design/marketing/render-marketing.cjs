#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const sharp = require("sharp");

const marketingDirectory = __dirname;
const designDirectory = path.resolve(marketingDirectory, "..");
const capturesDirectory = path.join(marketingDirectory, "captures");
const appStoreDirectory = path.join(marketingDirectory, "app-store");
const repositoryDirectory = path.join(marketingDirectory, "repository");
const regularFontPath = path.join(designDirectory, "../Mosaic/Resources/Fonts/Fraunces72ptSoft-Regular.ttf");
const semiboldFontPath = path.join(designDirectory, "../Mosaic/Resources/Fonts/Fraunces72ptSoft-SemiBold.ttf");
const appIconPath = path.join(designDirectory, "brand/mosaic-app-icon-master.png");

const WIDTH = 1320;
const HEIGHT = 2868;
const screen = { x: 166, y: 678, width: 988, height: 2148, radius: 102 };

const scenes = [
  {
    id: "home",
    filename: "01-together.png",
    eyebrow: "TOGETHER",
    lines: ["Small acts.", "One shared story."],
    background: ["#FBF8F1", "#E7EEE9"],
    ink: "#25221F",
    accent: "#5A47F2",
    tile: "#7D9A83"
  },
  {
    id: "mission",
    filename: "02-start-small.png",
    eyebrow: "START SMALL",
    lines: ["Choose one", "meaningful mission."],
    background: ["#FFF7E8", "#F7E1DA"],
    ink: "#25221F",
    accent: "#F56E3E",
    tile: "#E4A6B4"
  },
  {
    id: "privacy",
    filename: "03-private-by-design.png",
    eyebrow: "PRIVATE BY DESIGN",
    lines: ["Keep every", "proof private."],
    background: ["#F7F4EA", "#DCEBF0"],
    ink: "#25221F",
    accent: "#5A47F2",
    tile: "#7EB7CD"
  },
  {
    id: "placement",
    filename: "04-add-your-piece.png",
    eyebrow: "ADD YOUR PIECE",
    lines: ["Create your tile.", "Pass it on."],
    background: ["#FBF3E8", "#F2DDE4"],
    ink: "#25221F",
    accent: "#F56E3E",
    tile: "#D6A937"
  },
  {
    id: "reveal",
    filename: "05-the-reveal.png",
    eyebrow: "THE REVEAL",
    lines: ["Reveal what you", "made together."],
    background: ["#2B1C14", "#0F0D0B"],
    ink: "#F7F1E7",
    accent: "#D6A937",
    tile: "#F56E3E",
    dark: true
  }
];

function fontData(pathname) {
  return fs.readFileSync(pathname).toString("base64");
}

const fonts = {
  regular: fontData(regularFontPath),
  semibold: fontData(semiboldFontPath)
};

function ensureInputs() {
  for (const scene of scenes) {
    const input = path.join(capturesDirectory, `${scene.id}.png`);
    if (!fs.existsSync(input)) {
      throw new Error(`Missing simulator capture: ${input}. Run npm run marketing:capture first.`);
    }
  }
  fs.mkdirSync(appStoreDirectory, { recursive: true });
  fs.mkdirSync(repositoryDirectory, { recursive: true });
}

function fontFaceStyles() {
  return `
    @font-face { font-family: "Fraunces"; src: url("data:font/ttf;base64,${fonts.regular}"); font-weight: 400; }
    @font-face { font-family: "Fraunces"; src: url("data:font/ttf;base64,${fonts.semibold}"); font-weight: 650; }
  `;
}

function backgroundSVG(scene) {
  const title = scene.lines.map((line, index) =>
    `<tspan x="92" dy="${index === 0 ? 0 : 126}">${line}</tspan>`
  ).join("");
  const goldCrack = scene.dark
    ? `<path d="M1128 94l-54 82 32 48-92 88 38 58-70 92" fill="none" stroke="#D6A937" stroke-width="9" stroke-linecap="round" stroke-linejoin="round" opacity=".78"/>`
    : "";

  return Buffer.from(`
    <svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">
      <defs>
        <style>${fontFaceStyles()}</style>
        <linearGradient id="background" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="${scene.background[0]}"/>
          <stop offset="1" stop-color="${scene.background[1]}"/>
        </linearGradient>
        <linearGradient id="shell" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#373634"/>
          <stop offset=".45" stop-color="#070707"/>
          <stop offset="1" stop-color="#292826"/>
        </linearGradient>
        <filter id="shadow" x="-30%" y="-20%" width="160%" height="170%">
          <feDropShadow dx="0" dy="34" stdDeviation="30" flood-color="#000000" flood-opacity=".28"/>
        </filter>
        <pattern id="grain" width="47" height="43" patternUnits="userSpaceOnUse">
          <circle cx="8" cy="10" r="1.4" fill="${scene.ink}" opacity=".045"/>
          <circle cx="31" cy="28" r=".9" fill="${scene.ink}" opacity=".04"/>
        </pattern>
      </defs>
      <rect width="${WIDTH}" height="${HEIGHT}" fill="url(#background)"/>
      <rect width="${WIDTH}" height="${HEIGHT}" fill="url(#grain)"/>
      <g opacity=".9">
        <rect x="1038" y="116" width="112" height="112" rx="28" fill="${scene.tile}" transform="rotate(7 1094 172)"/>
        <path d="M1066 173h56M1094 145v56" stroke="${scene.accent}" stroke-width="11" stroke-linecap="round" opacity=".72"/>
        <circle cx="1194" cy="300" r="28" fill="${scene.accent}" opacity=".22"/>
      </g>
      ${goldCrack}
      <text x="92" y="145" fill="${scene.accent}" font-family="Arial, sans-serif" font-size="35" font-weight="700" letter-spacing="7">${scene.eyebrow}</text>
      <text x="92" y="290" fill="${scene.ink}" font-family="Fraunces, Georgia, serif" font-size="112" font-weight="650" letter-spacing="-2">${title}</text>
      <rect x="138" y="650" width="1044" height="2208" rx="132" fill="url(#shell)" filter="url(#shadow)"/>
      <rect x="150" y="662" width="1020" height="2184" rx="120" fill="none" stroke="#FFFFFF" stroke-opacity=".28" stroke-width="3"/>
    </svg>
  `);
}

function roundedMask(width, height, radius) {
  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><rect width="${width}" height="${height}" rx="${radius}" fill="#fff"/></svg>`);
}

async function renderScene(scene) {
  const capturePath = path.join(capturesDirectory, `${scene.id}.png`);
  const roundedScreenshot = await sharp(capturePath)
    .resize(screen.width, screen.height, { fit: "fill" })
    .composite([{ input: roundedMask(screen.width, screen.height, screen.radius), blend: "dest-in" }])
    .png()
    .toBuffer();

  const output = path.join(appStoreDirectory, scene.filename);
  await sharp(backgroundSVG(scene))
    .composite([{ input: roundedScreenshot, left: screen.x, top: screen.y }])
    .flatten({ background: scene.background[0] })
    .removeAlpha()
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toFile(output);
  return output;
}

async function roundedImage(pathname, width, height, radius) {
  return sharp(pathname)
    .resize(width, height, { fit: "cover" })
    .composite([{ input: roundedMask(width, height, radius), blend: "dest-in" }])
    .png()
    .toBuffer();
}

async function renderHero() {
  const heroWidth = 2400;
  const heroHeight = 1200;
  const icon = await roundedImage(appIconPath, 520, 520, 112);
  const heroSVG = Buffer.from(`
    <svg xmlns="http://www.w3.org/2000/svg" width="${heroWidth}" height="${heroHeight}" viewBox="0 0 ${heroWidth} ${heroHeight}">
      <defs>
        <style>${fontFaceStyles()}</style>
        <linearGradient id="hero" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#FBF8F1"/>
          <stop offset=".55" stop-color="#F4E6E9"/>
          <stop offset="1" stop-color="#DDE9E4"/>
        </linearGradient>
        <filter id="iconShadow" x="-30%" y="-30%" width="160%" height="180%">
          <feDropShadow dx="0" dy="28" stdDeviation="28" flood-color="#352A23" flood-opacity=".22"/>
        </filter>
        <pattern id="grain" width="41" height="37" patternUnits="userSpaceOnUse">
          <circle cx="7" cy="8" r="1.3" fill="#5A47F2" opacity=".05"/>
          <circle cx="29" cy="25" r="1" fill="#B89E80" opacity=".08"/>
        </pattern>
      </defs>
      <rect width="${heroWidth}" height="${heroHeight}" rx="64" fill="url(#hero)"/>
      <rect width="${heroWidth}" height="${heroHeight}" rx="64" fill="url(#grain)"/>
      <rect x="134" y="322" width="552" height="552" rx="126" fill="#FFFFFF" opacity=".72" filter="url(#iconShadow)"/>
      <text x="820" y="480" fill="#25221F" font-family="Fraunces, Georgia, serif" font-size="244" font-weight="650" letter-spacing="-7">Mosaic</text>
      <text x="830" y="628" fill="#5A47F2" font-family="Arial, sans-serif" font-size="49" font-weight="700" letter-spacing="6">SMALL ACTS. ONE SHARED STORY.</text>
      <text x="830" y="745" fill="#4E4944" font-family="Arial, sans-serif" font-size="44">Verified kindness becomes a shared ceramic artwork.</text>
      <g font-family="Arial, sans-serif" font-size="31" font-weight="700" fill="#25221F">
        <rect x="830" y="835" width="224" height="76" rx="38" fill="#FFFFFF" opacity=".75"/><text x="877" y="884">SwiftUI</text>
        <rect x="1080" y="835" width="248" height="76" rx="38" fill="#FFFFFF" opacity=".75"/><text x="1128" y="884">Supabase</text>
        <rect x="1354" y="835" width="360" height="76" rx="38" fill="#FFFFFF" opacity=".75"/><text x="1402" y="884">Privacy by design</text>
      </g>
      <g transform="translate(1960 180) rotate(7)">
        <rect width="164" height="164" rx="36" fill="#E4A6B4" stroke="#5A47F2" stroke-width="12"/>
        <path d="M48 88c18 28 50 28 68 0M82 45v38" fill="none" stroke="#5A47F2" stroke-width="12" stroke-linecap="round"/>
      </g>
      <path d="M1990 865l70-68-24-48 82-68-14-52 92-72" fill="none" stroke="#D6A937" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" opacity=".82"/>
    </svg>
  `);
  const output = path.join(repositoryDirectory, "mosaic-repository-hero.png");
  await sharp(heroSVG)
    .composite([{ input: icon, left: 150, top: 338 }])
    .flatten({ background: "#FBF8F1" })
    .removeAlpha()
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toFile(output);
  return output;
}

async function renderGallery(outputs) {
  const width = 2400;
  const height = 1150;
  const thumbWidth = 420;
  const thumbHeight = 913;
  const gap = 45;
  const startX = 60;
  const top = 100;
  const background = Buffer.from(`
    <svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">
      <defs>
        <linearGradient id="gallery" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#201D19"/><stop offset="1" stop-color="#0F0D0B"/></linearGradient>
        <filter id="shadow" x="-30%" y="-20%" width="160%" height="170%"><feDropShadow dx="0" dy="22" stdDeviation="22" flood-color="#000" flood-opacity=".48"/></filter>
      </defs>
      <rect width="${width}" height="${height}" rx="44" fill="url(#gallery)"/>
      <circle cx="2180" cy="90" r="170" fill="#D6A937" opacity=".08"/>
      <path d="M90 1090l120-92-38-54 106-82" fill="none" stroke="#D6A937" stroke-width="8" opacity=".34"/>
    </svg>
  `);
  const composites = [];
  for (let index = 0; index < outputs.length; index += 1) {
    const thumbnail = await roundedImage(outputs[index], thumbWidth, thumbHeight, 34);
    composites.push({ input: thumbnail, left: startX + index * (thumbWidth + gap), top });
  }
  const output = path.join(repositoryDirectory, "mosaic-app-store-gallery.png");
  await sharp(background)
    .composite(composites)
    .flatten({ background: "#141210" })
    .removeAlpha()
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toFile(output);
  return output;
}

async function main() {
  ensureInputs();
  const outputs = [];
  for (const scene of scenes) {
    outputs.push(await renderScene(scene));
  }
  outputs.push(await renderHero());
  outputs.push(await renderGallery(outputs.slice(0, scenes.length)));
  for (const output of outputs) {
    process.stdout.write(`Rendered ${path.relative(process.cwd(), output)}\n`);
  }
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
