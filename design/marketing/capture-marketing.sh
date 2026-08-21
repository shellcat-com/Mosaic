#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CAPTURE_DIR="${SCRIPT_DIR}/captures"
DERIVED_DATA="${PROJECT_ROOT}/build/MarketingDerivedData"
DEVICE_NAME="${MOSAIC_MARKETING_DEVICE:-iPhone 17 Pro Max}"
BUNDLE_ID="com.biswaskhatiwada.mosaicapp"

mkdir -p "${CAPTURE_DIR}"

DEVICE_LINE="$(xcrun simctl list devices available | rg -m 1 "^[[:space:]]+${DEVICE_NAME} \\(" || true)"
if [[ -z "${DEVICE_LINE}" ]]; then
  echo "No available simulator named '${DEVICE_NAME}'." >&2
  exit 1
fi

DEVICE_UDID="$(printf '%s' "${DEVICE_LINE}" | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')"
if [[ ! "${DEVICE_UDID}" =~ ^[0-9A-F-]{36}$ ]]; then
  echo "Could not resolve simulator UDID from: ${DEVICE_LINE}" >&2
  exit 1
fi

reset_status_bar() {
  xcrun simctl status_bar "${DEVICE_UDID}" clear >/dev/null 2>&1 || true
}
trap reset_status_bar EXIT

xcrun simctl boot "${DEVICE_UDID}" >/dev/null 2>&1 || true
xcrun simctl bootstatus "${DEVICE_UDID}" -b
xcrun simctl ui "${DEVICE_UDID}" appearance light
xcrun simctl status_bar "${DEVICE_UDID}" override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3 \
  --cellularBars 4

echo "Building Mosaic for ${DEVICE_NAME}…"
if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --spec "${PROJECT_ROOT}/project.yml" >/dev/null
fi
xcodebuild \
  -project "${PROJECT_ROOT}/Mosaic.xcodeproj" \
  -scheme Mosaic \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=${DEVICE_UDID}" \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGNING_ALLOWED=NO \
  -quiet \
  build

APP_PATH="${DERIVED_DATA}/Build/Products/Debug-iphonesimulator/Mosaic.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Built app not found at ${APP_PATH}." >&2
  exit 1
fi

xattr -cr "${APP_PATH}"
/usr/bin/codesign --force --deep --sign - "${APP_PATH}" >/dev/null
xcrun simctl install "${DEVICE_UDID}" "${APP_PATH}"
# A fresh simulator install is registered asynchronously by LaunchServices.
# Let that registration settle before asking simctl to launch the first fixture.
sleep 35

for SCENE in home mission privacy placement organizer reveal; do
  OUTPUT="${CAPTURE_DIR}/${SCENE}.png"
  xcrun simctl terminate "${DEVICE_UDID}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
  xcrun simctl launch "${DEVICE_UDID}" "${BUNDLE_ID}" \
    -marketing-preview "${SCENE}" \
    -AppleLanguages "(en)" \
    -AppleLocale "en_US"
  # SwiftUI's first render and bundled font registration need a few seconds on a
  # newly installed simulator build. A fixed wait keeps every fixture consistent.
  sleep 6
  xcrun simctl io "${DEVICE_UDID}" screenshot "${OUTPUT}"
  echo "Captured ${SCENE}: ${OUTPUT}"
done

xcrun simctl terminate "${DEVICE_UDID}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
