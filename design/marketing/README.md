# Mosaic marketing assets

This directory contains reproducible, real-UI marketing assets for Mosaic. The five App Store images are composed from debug-only simulator fixtures; no product screen is generated or fabricated.

## Generate everything

Requirements: macOS, Xcode 26+, an available iPhone 17 Pro Max simulator, Node.js, and npm.

```sh
cd design
npm install
npm run marketing
```

The pipeline builds the app, launches the six `-marketing-preview` routes, fixes the simulator status bar at 9:41, captures the real UI, renders the final artwork, and validates every output. The organizer route supplies synthetic pending evidence for the hackathon moderation demo and remains compiled out of Release.

## Outputs

- `captures/` — source simulator screenshots at 1320 × 2868.
- `app-store/` — five opaque RGB App Store PNGs at 1320 × 2868.
- `repository/` — the GitHub hero and five-panel gallery.

Set `MOSAIC_MARKETING_DEVICE` to use a differently named compatible 6.9-inch simulator. The output dimensions must remain 1320 × 2868.
