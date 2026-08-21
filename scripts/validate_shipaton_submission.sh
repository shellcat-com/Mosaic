#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
screenshot="$repo_root/submission/Mosaic-Shipaton-Screenshot-1179x2556.png"
video="$repo_root/submission/Mosaic-Shipaton-Demo.mp4"
captions="$repo_root/submission/Mosaic-Shipaton-Demo.srt"
icon="$repo_root/Mosaic/Resources/Assets.xcassets/AppIcon.appiconset/MosaicAppIcon.png"
submission_copy="$repo_root/docs/SHIPATON_SUBMISSION.md"
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

width="$(sips -g pixelWidth "$screenshot" | awk '/pixelWidth:/ { print $2 }')"
height="$(sips -g pixelHeight "$screenshot" | awk '/pixelHeight:/ { print $2 }')"
if [[ "$width" != "1179" || "$height" != "2556" ]]; then
  echo "Shipaton screenshot must be exactly 1179x2556; found ${width}x${height}." >&2
  exit 1
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
  echo "Video duration: ${duration} seconds"
else
  if [[ "$require_video" == true ]]; then
    echo "Required Shipaton video is missing: $video" >&2
    exit 1
  fi
  echo "Video not present yet: record the genuine Test Store purchase, then export to $video"
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
fi

echo "Screenshot: ${width}x${height}"
echo "App icon: ${icon_width}x${icon_height}"
echo "Captions: ready"
