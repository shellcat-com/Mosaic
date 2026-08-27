#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_spec="$repo_root/project.yml"
info_plist="$repo_root/Mosaic/Resources/Info.plist"
entitlements="$repo_root/Mosaic/Resources/Mosaic.entitlements"
privacy_manifest="$repo_root/Mosaic/Resources/PrivacyInfo.xcprivacy"
icon="$repo_root/Mosaic/Resources/Assets.xcassets/AppIcon.appiconset/MosaicAppIcon.png"
screenshots="$repo_root/design/app-store-screenshots/6.9-inch"

for required in "$project_spec" "$info_plist" "$entitlements" "$privacy_manifest" "$icon"; do
  test -f "$required"
done

plutil -lint "$info_plist" "$entitlements" "$privacy_manifest" \
  "$repo_root/Mosaic.xcodeproj/project.pbxproj"

required_catalog=(
  organizer_plus_v1
  organizer_plus
  organizer_monthly
  organizer_annual
  mosaic_event_pass_v2
  PASS
)
for identifier in "${required_catalog[@]}"; do
  rg -q --fixed-strings "$identifier" \
    "$repo_root/MosaicV3/Domain/BillingModels.swift" \
    "$repo_root/supabase/functions/_shared/revenuecat.ts" \
    "$repo_root/docs/MONETIZATION_SETUP.md" || {
      echo "Missing release catalog identifier: $identifier" >&2
      exit 1
    }
done

rg -q 'com\.apple\.InAppPurchase' "$project_spec"
rg -q 'com\.apple\.SignInWithApple' "$project_spec"
rg -q 'ITSAppUsesNonExemptEncryption: true' "$project_spec"
rg -q 'TARGETED_DEVICE_FAMILY: "1"' "$project_spec"
if rg -q 'RevenueCatUI' "$project_spec"; then
  echo "RevenueCatUI must remain absent; Mosaic uses its native paywall." >&2
  exit 1
fi

icon_width="$(sips -g pixelWidth "$icon" | awk '/pixelWidth:/ { print $2 }')"
icon_height="$(sips -g pixelHeight "$icon" | awk '/pixelHeight:/ { print $2 }')"
icon_alpha="$(sips -g hasAlpha "$icon" | awk '/hasAlpha:/ { print $2 }')"
if [[ "$icon_width" != 1024 || "$icon_height" != 1024 || "$icon_alpha" != no ]]; then
  echo "App icon must be opaque 1024x1024; found ${icon_width}x${icon_height}, alpha=${icon_alpha}." >&2
  exit 1
fi

screenshot_files=()
while IFS= read -r screenshot; do
  screenshot_files+=("$screenshot")
done < <(find "$screenshots" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) | sort)
if [[ "${#screenshot_files[@]}" -ne 7 ]]; then
  echo "Expected seven App Store screenshots; found ${#screenshot_files[@]}." >&2
  exit 1
fi
for screenshot in "${screenshot_files[@]}"; do
  width="$(sips -g pixelWidth "$screenshot" | awk '/pixelWidth:/ { print $2 }')"
  height="$(sips -g pixelHeight "$screenshot" | awk '/pixelHeight:/ { print $2 }')"
  alpha="$(sips -g hasAlpha "$screenshot" | awk '/hasAlpha:/ { print $2 }')"
  if [[ "$width" != 1320 || "$height" != 2868 || "$alpha" != no ]]; then
    echo "Invalid App Store screenshot $(basename "$screenshot"): ${width}x${height}, alpha=${alpha}." >&2
    exit 1
  fi
done

if rg -n 'TODO|FIXME|HACK|fatalError\(|try!|as!|\bprint\(' "$repo_root/MosaicV3" -g '*.swift'; then
  echo "Production code-quality marker found in MosaicV3." >&2
  exit 1
fi

echo "App Store release structure: ready"
