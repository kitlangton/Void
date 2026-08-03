#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/Void.xcodeproj}"
SCHEME="${SCHEME:-Void}"
DEVICE_NAME="${DEVICE_NAME:-iPhone 16 Pro}"
SIMULATOR_OS="${SIMULATOR_OS:-18.5}"
OUTPUT_PATH="${OUTPUT_PATH:-$ROOT_DIR/build/screenshots/streak-page.png}"
LAUNCH_DELAY_SECONDS="${LAUNCH_DELAY_SECONDS:-3}"

run() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
  "$@"
}

get_device_id() {
  local runtime_key="com.apple.CoreSimulator.SimRuntime.iOS-${SIMULATOR_OS//./-}"
  local json_file
  json_file="$(mktemp -t void-simulators.XXXXXX.json)"

  xcrun simctl list devices available -j > "$json_file"

  /usr/bin/python3 - "$json_file" "$runtime_key" "$DEVICE_NAME" <<'PY'
import json
import sys

json_file, runtime_key, device_name = sys.argv[1], sys.argv[2], sys.argv[3]
with open(json_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

for device in data.get("devices", {}).get(runtime_key, []):
    if device.get("name") == device_name and device.get("isAvailable"):
        print(device.get("udid", ""))
        break
PY

  rm -f "$json_file"
}

BUILD_SETTINGS=$(xcodebuild -showBuildSettings -project "$PROJECT_PATH" -scheme "$SCHEME" -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=$SIMULATOR_OS")
TARGET_BUILD_DIR=$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/TARGET_BUILD_DIR/ { print $2; exit }')
FULL_PRODUCT_NAME=$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/FULL_PRODUCT_NAME/ { print $2; exit }')

[[ -n "$TARGET_BUILD_DIR" && -n "$FULL_PRODUCT_NAME" ]] || {
  printf 'Failed to resolve simulator build output path.\n' >&2
  exit 1
}

APP_PATH="$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
DEVICE_ID="$(get_device_id)"

[[ -n "$DEVICE_ID" ]] || {
  printf 'Could not find simulator %s (%s).\n' "$DEVICE_NAME" "$SIMULATOR_OS" >&2
  exit 1
}

mkdir -p "$(dirname "$OUTPUT_PATH")"

killall Simulator >/dev/null 2>&1 || true
killall com.apple.CoreSimulator.CoreSimulatorService >/dev/null 2>&1 || true

run open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID"
run xcodebuild build -project "$PROJECT_PATH" -scheme "$SCHEME" -destination "id=$DEVICE_ID" CODE_SIGNING_ALLOWED=NO
run xcrun simctl boot "$DEVICE_ID"
run xcrun simctl bootstatus "$DEVICE_ID" -b
run xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl terminate "$DEVICE_ID" com.kitlangton.Void >/dev/null 2>&1 || true
run env SIMCTL_CHILD_VOID_SCREENSHOT_MODE=1 SIMCTL_CHILD_VOID_SCREENSHOT_PAGE=streak xcrun simctl launch "$DEVICE_ID" com.kitlangton.Void
run sleep "$LAUNCH_DELAY_SECONDS"
run xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_PATH"

printf 'Saved screenshot to %s\n' "$OUTPUT_PATH"
