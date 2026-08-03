#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/Void.xcodeproj}"
SCHEME="${SCHEME:-Void}"
CONFIGURATION="${CONFIGURATION:-Release}"
TEAM_ID="${TEAM_ID:-QC99C9JE59}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/testflight}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT_DIR/scripts/export-options-app-store.plist}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M%S)}"
VERSION="${VERSION:-}"
XCODEBUILD_JOBS="${XCODEBUILD_JOBS:-4}"

APPLE_ID="${APPLE_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
APPLE_APP_PASSWORD_KEYCHAIN_ITEM="${APPLE_APP_PASSWORD_KEYCHAIN_ITEM:-VOID_APPSTORE}"
ASC_PROVIDER_PUBLIC_ID="${ASC_PROVIDER_PUBLIC_ID:-}"

APP_STORE_CONNECT_API_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-}"
APP_STORE_CONNECT_API_ISSUER_ID="${APP_STORE_CONNECT_API_ISSUER_ID:-}"
APP_STORE_CONNECT_API_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-}"

ARCHIVE_ONLY=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: scripts/testflight.sh [options]

Archive, export, and optionally upload Void to TestFlight.

Options:
  --version <version>         Override MARKETING_VERSION for the archive
  --build-number <number>     Override CURRENT_PROJECT_VERSION (default: timestamp)
  --archive-only              Build the xcarchive and ipa, but skip App Store Connect upload
  --dry-run                   Print the resolved commands without executing them
  --help                      Show this help text

Authentication:
  Option A: Team App Store Connect API key
    export APP_STORE_CONNECT_API_KEY_ID=...
    export APP_STORE_CONNECT_API_ISSUER_ID=...
    export APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_XXXX.p8

  Option B: Apple ID + app-specific password
    export APPLE_ID=you@example.com
    export APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx

  Or store the password once in the keychain and upload using:
    export APPLE_ID=you@example.com
    export APPLE_APP_PASSWORD_KEYCHAIN_ITEM=VOID_APPSTORE
    security add-generic-password -U -a "$APPLE_ID" -s "VOID_APPSTORE" -w "$APPLE_APP_PASSWORD"

Examples:
  scripts/testflight.sh --archive-only
  VERSION=1.1.1 scripts/testflight.sh
  APP_STORE_CONNECT_API_KEY_ID=... APP_STORE_CONNECT_API_ISSUER_ID=... APP_STORE_CONNECT_API_KEY_PATH=... scripts/testflight.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --archive-only)
      ARCHIVE_ONLY=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

run() {
  printf '+ '
  local redact_next=0
  local argument
  for argument in "$@"; do
    if [[ "$redact_next" -eq 1 ]]; then
      printf '<redacted> '
      redact_next=0
      continue
    fi

    printf '%q ' "$argument"
    case "$argument" in
      -u|-p|--username|--password|--api-key|--api-issuer|--auth-string)
        redact_next=1
        ;;
    esac
  done
  printf '\n'

  if [[ "$DRY_RUN" -eq 0 ]]; then
    "$@" || return $?
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

require_file() {
  [[ -f "$1" ]] || {
    printf 'Missing required file: %s\n' "$1" >&2
    exit 1
  }
}

keychain_account() {
  security find-generic-password -s "$1" 2>/dev/null \
    | sed -n 's/^[[:space:]]*"acct"<blob>="\(.*\)"$/\1/p' \
    | head -n 1
}

json_read_provider_id() {
  local json_file="$1"
  local team_id="$2"
  /usr/bin/python3 - "$json_file" "$team_id" <<'PY'
import json
import sys

path, team_id = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

for provider in data.get('included', []):
    attributes = provider.get('attributes', {})
    if attributes.get('developerTeamId') == team_id:
        print(provider.get('id', ''))
        break
PY
}

resolve_provider_public_id() {
  if [[ -n "$ASC_PROVIDER_PUBLIC_ID" ]]; then
    return
  fi

  local probe_file
  probe_file="$(mktemp -t void-providers.XXXXXX.json)"
  local -a cmd=(xcrun altool --list-providers --output-format json)

  if [[ -n "$APP_STORE_CONNECT_API_KEY_ID" || -n "$APP_STORE_CONNECT_API_ISSUER_ID" || -n "$APP_STORE_CONNECT_API_KEY_PATH" ]]; then
    [[ -n "$APP_STORE_CONNECT_API_KEY_ID" && -n "$APP_STORE_CONNECT_API_ISSUER_ID" && -n "$APP_STORE_CONNECT_API_KEY_PATH" ]] || {
      printf 'Provider lookup via API key requires APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_API_ISSUER_ID, and APP_STORE_CONNECT_API_KEY_PATH.\n' >&2
      exit 1
    }

    require_file "$APP_STORE_CONNECT_API_KEY_PATH"
    export API_PRIVATE_KEYS_DIR
    API_PRIVATE_KEYS_DIR="$(dirname "$APP_STORE_CONNECT_API_KEY_PATH")"
    cmd+=(--api-key "$APP_STORE_CONNECT_API_KEY_ID" --api-issuer "$APP_STORE_CONNECT_API_ISSUER_ID")
  else
    [[ -n "$APPLE_ID" ]] || {
      printf 'Provider lookup requires APPLE_ID or App Store Connect API key credentials.\n' >&2
      exit 1
    }

    if [[ -n "$APPLE_APP_PASSWORD" ]]; then
      export APPLE_APP_PASSWORD
      cmd+=(-u "$APPLE_ID" -p "@env:APPLE_APP_PASSWORD")
    else
      cmd+=(-u "$APPLE_ID" -p "@keychain:$APPLE_APP_PASSWORD_KEYCHAIN_ITEM")
    fi
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Auto-detecting provider public ID for team %s\n' "$TEAM_ID"
    return
  fi

  "${cmd[@]}" > "$probe_file"
  ASC_PROVIDER_PUBLIC_ID="$(json_read_provider_id "$probe_file" "$TEAM_ID")"
  rm -f "$probe_file"

  [[ -n "$ASC_PROVIDER_PUBLIC_ID" ]] || {
    printf 'Could not auto-detect provider public ID for team %s. Set ASC_PROVIDER_PUBLIC_ID explicitly.\n' "$TEAM_ID" >&2
    exit 1
  }
}

build_authenticated_altool_command() {
  local operation="$1"
  local ipa_path="$2"
  local -a cmd=(xcrun altool "$operation" "$ipa_path" --output-format json --show-progress)

  if [[ -n "$APP_STORE_CONNECT_API_KEY_ID" || -n "$APP_STORE_CONNECT_API_ISSUER_ID" || -n "$APP_STORE_CONNECT_API_KEY_PATH" ]]; then
    [[ -n "$APP_STORE_CONNECT_API_KEY_ID" && -n "$APP_STORE_CONNECT_API_ISSUER_ID" && -n "$APP_STORE_CONNECT_API_KEY_PATH" ]] || {
      printf 'App Store Connect authentication requires APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_API_ISSUER_ID, and APP_STORE_CONNECT_API_KEY_PATH.\n' >&2
      exit 1
    }

    require_file "$APP_STORE_CONNECT_API_KEY_PATH"
    export API_PRIVATE_KEYS_DIR
    API_PRIVATE_KEYS_DIR="$(dirname "$APP_STORE_CONNECT_API_KEY_PATH")"

    cmd+=(--api-key "$APP_STORE_CONNECT_API_KEY_ID" --api-issuer "$APP_STORE_CONNECT_API_ISSUER_ID")
  else
    [[ -n "$APPLE_ID" ]] || {
      printf 'App Store Connect authentication requires APPLE_ID or API key credentials.\n' >&2
      exit 1
    }

    if [[ -n "$APPLE_APP_PASSWORD" ]]; then
      export APPLE_APP_PASSWORD
      cmd+=(-u "$APPLE_ID" -p "@env:APPLE_APP_PASSWORD")
    else
      cmd+=(-u "$APPLE_ID" -p "@keychain:$APPLE_APP_PASSWORD_KEYCHAIN_ITEM")
    fi

    if [[ -n "$ASC_PROVIDER_PUBLIC_ID" ]]; then
      cmd+=(--provider-public-id "$ASC_PROVIDER_PUBLIC_ID")
    fi
  fi

  printf '%s\0' "${cmd[@]}"
}

require_command xcodebuild
require_command xcrun

if [[ -z "$APPLE_ID" && -z "$APP_STORE_CONNECT_API_KEY_ID" ]]; then
  APPLE_ID="$(keychain_account "$APPLE_APP_PASSWORD_KEYCHAIN_ITEM")"
fi

if [[ "$ARCHIVE_ONLY" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
  resolve_provider_public_id
fi

mkdir -p "$BUILD_DIR"

ARCHIVE_PATH="$BUILD_DIR/$SCHEME-$BUILD_NUMBER.xcarchive"
EXPORT_PATH="$BUILD_DIR/export-$BUILD_NUMBER"
IPA_PATH=""

require_file "$EXPORT_OPTIONS_PLIST"

XCODEBUILD_ARCHIVE=(
  xcodebuild archive
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -jobs "$XCODEBUILD_JOBS"
  -archivePath "$ARCHIVE_PATH"
  -destination "generic/platform=iOS"
  -allowProvisioningUpdates
  DEVELOPMENT_TEAM="$TEAM_ID"
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
)

if [[ -n "$VERSION" ]]; then
  XCODEBUILD_ARCHIVE+=(MARKETING_VERSION="$VERSION")
fi

XCODEBUILD_EXPORT=(
  xcodebuild -exportArchive
  -archivePath "$ARCHIVE_PATH"
  -exportPath "$EXPORT_PATH"
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
  -allowProvisioningUpdates
)

printf 'Project: %s\n' "$PROJECT_PATH"
printf 'Scheme: %s\n' "$SCHEME"
printf 'Configuration: %s\n' "$CONFIGURATION"
printf 'Team ID: %s\n' "$TEAM_ID"
printf 'Provider public ID: %s\n' "${ASC_PROVIDER_PUBLIC_ID:-auto}"
printf 'Build number: %s\n' "$BUILD_NUMBER"
if [[ -n "$VERSION" ]]; then
  printf 'Version override: %s\n' "$VERSION"
fi
printf 'Archive path: %s\n' "$ARCHIVE_PATH"
printf 'Export path: %s\n' "$EXPORT_PATH"

run "${XCODEBUILD_ARCHIVE[@]}"
run "${XCODEBUILD_EXPORT[@]}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'Dry-run complete; skipping artifact checks and upload.\n'
  exit 0
fi

IPA_PATH="$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print -quit)"
[[ -n "$IPA_PATH" ]] || {
  printf 'No .ipa found in export path: %s\n' "$EXPORT_PATH" >&2
  exit 1
}

require_file "$IPA_PATH"
printf 'IPA ready: %s\n' "$IPA_PATH"

if [[ "$ARCHIVE_ONLY" -eq 1 ]]; then
  printf 'Archive-only mode enabled; skipping upload.\n'
  exit 0
fi

printf 'Validating with App Store Connect...\n'
mapfile -d '' -t VALIDATE_CMD < <(build_authenticated_altool_command --validate-app "$IPA_PATH")
run "${VALIDATE_CMD[@]}"

printf 'Uploading to App Store Connect...\n'
mapfile -d '' -t UPLOAD_CMD < <(build_authenticated_altool_command --upload-package "$IPA_PATH")
UPLOAD_CMD+=(--wait)
run "${UPLOAD_CMD[@]}"

printf 'Upload processed successfully. The build is ready in App Store Connect / TestFlight.\n'
