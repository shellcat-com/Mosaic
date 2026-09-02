# Mosaic v3 simulator UI review

Captured from the real SwiftUI target on iPhone 17 Pro / iOS 26.3 on 2026-08-25.

The signed-in screens use the Debug-only `MOSAIC_SHOWCASE_SCREEN` fixture so product flows can be reviewed without creating a production account or modifying hosted data. Production authentication and networking remain unchanged. The gallery fixture reuses bundled artwork images solely as stand-ins for event photographs; the app's real gallery accepts only developed `EventPhoto` JPEGs from the in-app camera.

- `00-sign-in.png`: production signed-out state
- `01-home.png`: active and revealed Mosaic library
- `02-create-basics.png`: step 1 of the six-step organizer flow
- `03-active-mosaic.png`: tile fronts and fixed reveal countdown
- `04-revealed-artwork.png`: completed artwork outcome
- `05-photo-gallery.png`: separate photo destination
- `06-recap-builder.png`: photo-only recap selection
- `07-camera.png`: event-scoped disposable camera
- `overview.png`: contact sheet
