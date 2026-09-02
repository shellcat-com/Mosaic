# Repository Guidelines

## Project Structure & Module Organization

The shipping iOS app lives in `MosaicV3/`, organized into `Domain/`, `Infrastructure/`, `Stores/`, and SwiftUI views under `Features/`. `Mosaic/` is legacy; `project.yml` includes only selected shared code and resources from it. Unit tests are in `MosaicV3Tests/`, while UI journeys are in `MosaicV3UITests/`. Supabase migrations, Edge Functions, and database tests live under `supabase/`. Keep documentation in `docs/`, website files in `site/`, and review assets in `design/`.

## Build, Test, and Development Commands

- `xcodegen generate` regenerates `Mosaic.xcodeproj` from `project.yml`; commit project-file changes with the spec.
- `xcodebuild -project Mosaic.xcodeproj -scheme Mosaic -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' test` builds the app and runs unit and UI tests.
- `./scripts/validate_app_store_release.sh` validates release configuration, privacy files, icons, and catalog contracts.
- `supabase start && supabase db reset && supabase test db` starts and verifies the local backend (Docker required).
- `supabase db lint --local --schema public --schema private` checks database schemas.
- `deno fmt --check supabase/functions` checks Edge Function formatting; use each function's `deno.json` when running its tests.

## Coding Style & Naming Conventions

Use four-space indentation in Swift and follow Swift API naming: `UpperCamelCase` for types and `lowerCamelCase` for members. Keep UI state `@MainActor`, isolate I/O behind actors or services, and preserve Domain/Store/Infrastructure boundaries. Use two-space indentation and `deno fmt` for TypeScript. Name SQL migrations `YYYYMMDDHHMMSS_description.sql`. Never hand-edit generated project settings when `project.yml` can express the change.

## Testing Guidelines

Use Swift Testing (`import Testing`, `@Test`) for unit tests and XCTest for UI automation. Name test files after the subject (`BillingTests.swift`) and tests after observable behavior. Add regression coverage beside every logic change. Run focused tests during development, then the full `Mosaic` scheme before opening a PR. No numeric coverage threshold is enforced; CI requires all unit, UI, backend-contract, formatting, and release-validation checks to pass.

## Commit & Pull Request Guidelines

History uses short, imperative subjects such as `Make release tests deterministic in CI`. Keep commits focused and avoid committing secrets or local configuration. PRs should explain the user-visible effect, identify affected app/backend areas, link relevant issues, and include simulator screenshots or recordings for UI changes. Call out migrations, configuration changes, and manual verification steps explicitly.

## Security & Configuration

Copy `Config/Local.xcconfig.example` to the ignored local file. Only public client keys belong in app configuration; keep service-role and RevenueCat secret keys in Supabase secrets. Review `SECURITY.md` before changing authentication, storage policies, billing, or invitation access.
