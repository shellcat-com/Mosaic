#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
screenshot="$repo_root/submission/Mosaic-Shipaton-Screenshot-1179x2556.png"
paywall_screenshot="$repo_root/submission/Mosaic-Shipaton-Paywall.png"
video="$repo_root/submission/Mosaic-Shipaton-Demo.mp4"
captions="$repo_root/submission/Mosaic-Shipaton-Demo.srt"
icon="$repo_root/Mosaic/Resources/Assets.xcassets/AppIcon.appiconset/MosaicAppIcon.png"
submission_copy="$repo_root/docs/SHIPATON_SUBMISSION.md"
project_spec="$repo_root/project.yml"
require_video=false
require_public_url=false

if [[ "${1:-}" == "--require-video" ]]; then
  require_video=true
elif [[ "${1:-}" == "--final" ]]; then
  require_video=true
  require_public_url=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--require-video|--final]" >&2
  exit 2
fi

test -f "$screenshot"
test -f "$captions"
test -f "$icon"
test -f "$submission_copy"
test -f "$repo_root/LICENSE"
test -f "$repo_root/README.md"
test -f "$project_spec"

required_catalog=(
  organizer_plus_v1
  organizer_plus
  organizer_monthly
  organizer_annual
  mosaic_event_pass_v2
  PASS
)
for identifier in "${required_catalog[@]}"; do
  if ! rg -q --fixed-strings "$identifier" \
    "$repo_root/MosaicV3/Domain/BillingModels.swift" \
    "$repo_root/supabase/migrations/20260826061805_v3_revenuecat_billing.sql" \
    "$submission_copy"; then
    echo "Missing RevenueCat catalog identifier: $identifier" >&2
    exit 1
  fi
done

if ! rg -q 'purchases-ios-spm' "$project_spec" || ! rg -q 'product: RevenueCat' "$project_spec"; then
  echo "The V3 project does not declare the RevenueCat Purchases package/product." >&2
  exit 1
fi
if rg -q 'RevenueCatUI' "$project_spec"; then
  echo "RevenueCatUI must remain absent; Mosaic uses the custom SwiftUI paywall." >&2
  exit 1
fi
for marker in 'Make room for more people' 'Participants remain completely free' 'server-authoritative' 'Next Gen only'; do
  if ! rg -q --fixed-strings "$marker" "$submission_copy" "$repo_root/README.md" "$repo_root/docs/SHIPATON_READINESS.md"; then
    echo "Current V3 submission copy is missing: $marker" >&2
    exit 1
  fi
done

width="$(sips -g pixelWidth "$screenshot" | awk '/pixelWidth:/ { print $2 }')"
height="$(sips -g pixelHeight "$screenshot" | awk '/pixelHeight:/ { print $2 }')"
if [[ "$width" != "1179" || "$height" != "2556" ]]; then
  echo "Shipaton screenshot must be exactly 1179x2556; found ${width}x${height}." >&2
  exit 1
fi
if [[ "$require_public_url" == true ]]; then
  screenshot_hash="$(shasum -a 256 "$screenshot" | awk '{print $1}')"
  if [[ "$screenshot_hash" == "ab62059a1730a89cc8bf9509fba656e98d8f5cc1864934f79917eb3ad0221c50" ]]; then
    echo "The legacy Shipaton screenshot is still present; capture the genuine V3 app before final submission." >&2
    exit 1
  fi
fi

icon_width="$(sips -g pixelWidth "$icon" | awk '/pixelWidth:/ { print $2 }')"
icon_height="$(sips -g pixelHeight "$icon" | awk '/pixelHeight:/ { print $2 }')"
if [[ "$icon_width" != "1024" || "$icon_height" != "1024" ]]; then
  echo "Shipaton app icon must be exactly 1024x1024; found ${icon_width}x${icon_height}." >&2
  exit 1
fi

if [[ -f "$video" ]]; then
  duration="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$video")"
  awk -v duration="$duration" 'BEGIN { if (duration >= 120) exit 1 }' || {
    echo "Shipaton video must be shorter than 120 seconds; found ${duration}." >&2
    exit 1
  }
  if [[ "$require_public_url" == true ]]; then
    awk -v duration="$duration" 'BEGIN { if (duration < 100 || duration > 110) exit 1 }' || {
      echo "Final Next Gen video should be 100–110 seconds; found ${duration}." >&2
      exit 1
    }
  fi
  echo "Video duration: ${duration} seconds"
else
  if [[ "$require_video" == true ]]; then
    echo "Required Shipaton video is missing: $video" >&2
    exit 1
  fi
  echo "Video not present yet: record the genuine Test Store purchase, then export to $video"
fi

if [[ -f "$paywall_screenshot" ]]; then
  paywall_width="$(sips -g pixelWidth "$paywall_screenshot" | awk '/pixelWidth:/ { print $2 }')"
  paywall_height="$(sips -g pixelHeight "$paywall_screenshot" | awk '/pixelHeight:/ { print $2 }')"
  if [[ "$paywall_width" -lt 1179 || "$paywall_height" -lt 2556 ]]; then
    echo "Paywall gallery image must be at least 1179x2556; found ${paywall_width}x${paywall_height}." >&2
    exit 1
  fi
else
  if [[ "$require_public_url" == true ]]; then
    echo "Final custom-paywall gallery image is missing: $paywall_screenshot" >&2
    exit 1
  fi
  echo "Paywall gallery image not present yet: capture the genuine V3 paywall at $paywall_screenshot"
fi

if [[ "$require_public_url" == true ]]; then
  if grep -q "ADD PUBLIC YOUTUBE OR VIMEO URL" "$submission_copy"; then
    echo "Public YouTube or Vimeo URL is still missing from docs/SHIPATON_SUBMISSION.md." >&2
    exit 1
  fi
  if ! grep -Eiq 'https://(www\.)?(youtube\.com|youtu\.be|vimeo\.com)/' "$submission_copy"; then
    echo "No public YouTube or Vimeo URL found in docs/SHIPATON_SUBMISSION.md." >&2
    exit 1
  fi
  video_url="$(rg -o 'https://(www\.)?(youtube\.com|youtu\.be|vimeo\.com)/[^ )]+' "$submission_copy" | head -1)"
  repo_url="$(rg -o 'https://github\.com/[^ /]+/[^ )]+' "$submission_copy" | head -1)"
  if ! curl --fail --silent --location --max-time 15 "$repo_url" >/dev/null; then
    echo "Public repository is not reachable while signed out: $repo_url" >&2
    exit 1
  fi
  if ! curl --fail --silent --location --max-time 15 "$video_url" >/dev/null; then
    echo "Public YouTube/Vimeo URL is not reachable: $video_url" >&2
    exit 1
  fi
fi

echo "Screenshot: ${width}x${height}"
echo "App icon: ${icon_width}x${icon_height}"
[[ -f "$paywall_screenshot" ]] && echo "Paywall gallery: ${paywall_width}x${paywall_height}"
echo "Captions: ready"
echo "RevenueCat V3 contract: ready"
