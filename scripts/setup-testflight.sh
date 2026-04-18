#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/Void.xcodeproj}"
SCHEME="${SCHEME:-Void}"
TEAM_ID="${TEAM_ID:-QC99C9JE59}"
KEYCHAIN_ITEM="${APPLE_APP_PASSWORD_KEYCHAIN_ITEM:-VOID_APPSTORE}"
XAPPSTORECONNECT_PATH="${XAPPSTORECONNECT_PATH:-$HOME/.xappstoreconnect}"

COLOR=1
STORE_PASSWORD=0
CHECK_ASC=0

APPLE_ID="${APPLE_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
APP_STORE_CONNECT_API_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-}"
APP_STORE_CONNECT_API_ISSUER_ID="${APP_STORE_CONNECT_API_ISSUER_ID:-}"
APP_STORE_CONNECT_API_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-}"
ASC_PROVIDER_PUBLIC_ID="${ASC_PROVIDER_PUBLIC_ID:-}"

usage() {
  cat <<'EOF'
Usage: scripts/setup-testflight.sh [options]

Audit the local machine for Void TestFlight prerequisites and optionally
store an app-specific password in the keychain.

Options:
  --store-password   Store APPLE_APP_PASSWORD in the keychain item name from
                     APPLE_APP_PASSWORD_KEYCHAIN_ITEM or default VOID_APPSTORE
  --check-asc        Attempt a lightweight App Store Connect auth probe when
                     enough credentials are available
  --no-color         Disable colored output
  --help             Show this help text

Environment variables this script understands:
  APPLE_ID
  APPLE_APP_PASSWORD
  APPLE_APP_PASSWORD_KEYCHAIN_ITEM
  APP_STORE_CONNECT_API_KEY_ID
  APP_STORE_CONNECT_API_ISSUER_ID
  APP_STORE_CONNECT_API_KEY_PATH
  TEAM_ID

Examples:
  scripts/setup-testflight.sh
  APPLE_ID=you@example.com APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx scripts/setup-testflight.sh --store-password
  APP_STORE_CONNECT_API_KEY_ID=... APP_STORE_CONNECT_API_ISSUER_ID=... APP_STORE_CONNECT_API_KEY_PATH=... scripts/setup-testflight.sh --check-asc
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --store-password)
      STORE_PASSWORD=1
      shift
      ;;
    --check-asc)
      CHECK_ASC=1
      shift
      ;;
    --no-color)
      COLOR=0
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

if [[ "$COLOR" -eq 1 ]]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  BOLD=""
  RESET=""
fi

section() {
  printf '\n%s%s%s\n' "$BOLD" "$1" "$RESET"
}

ok() {
  printf '%s[ok]%s %s\n' "$GREEN" "$RESET" "$1"
}

warn() {
  printf '%s[warn]%s %s\n' "$YELLOW" "$RESET" "$1"
}

fail() {
  printf '%s[fail]%s %s\n' "$RED" "$RESET" "$1"
}

info() {
  printf '%s[info]%s %s\n' "$BLUE" "$RESET" "$1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

keychain_item_exists() {
  security find-generic-password -s "$1" >/dev/null 2>&1
}

find_api_keys() {
  local dir
  for dir in \
    "$HOME/.appstoreconnect/private_keys" \
    "$HOME/.private_keys" \
    "$HOME/private_keys"
  do
    if [[ -d "$dir" ]]; then
      find "$dir" -maxdepth 1 -name 'AuthKey_*.p8' -print
    fi
  done
}

json_read() {
  local file="$1"
  local key="$2"
  /usr/bin/python3 - "$file" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
value = data.get(key, '')
if value is None:
    value = ''
sys.stdout.write(str(value))
PY
}

json_read_provider_id() {
  local file="$1"
  local team_id="$2"
  /usr/bin/python3 - "$file" "$team_id" <<'PY'
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

maybe_import_xappstoreconnect() {
  if [[ ! -f "$XAPPSTORECONNECT_PATH" ]]; then
    return
  fi

  local detected_key_id detected_issuer_id detected_private_key detected_key_path
  detected_key_id="$(json_read "$XAPPSTORECONNECT_PATH" keyId)"
  detected_issuer_id="$(json_read "$XAPPSTORECONNECT_PATH" issuerId)"
  detected_private_key="$(json_read "$XAPPSTORECONNECT_PATH" privateKey)"

  [[ -n "$APP_STORE_CONNECT_API_KEY_ID" ]] || APP_STORE_CONNECT_API_KEY_ID="$detected_key_id"
  [[ -n "$APP_STORE_CONNECT_API_ISSUER_ID" ]] || APP_STORE_CONNECT_API_ISSUER_ID="$detected_issuer_id"

  if [[ -n "$APP_STORE_CONNECT_API_KEY_ID" && -z "$APP_STORE_CONNECT_API_KEY_PATH" ]]; then
    APP_STORE_CONNECT_API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
  fi

  if [[ -n "$detected_private_key" && -n "$APP_STORE_CONNECT_API_KEY_PATH" && ! -f "$APP_STORE_CONNECT_API_KEY_PATH" ]]; then
    mkdir -p "$(dirname "$APP_STORE_CONNECT_API_KEY_PATH")"
    printf '%s\n' "$detected_private_key" > "$APP_STORE_CONNECT_API_KEY_PATH"
    chmod 600 "$APP_STORE_CONNECT_API_KEY_PATH"
  fi
}

store_password_if_requested() {
  if [[ "$STORE_PASSWORD" -eq 0 ]]; then
    return
  fi

  section "Store Password"

  if [[ -z "$APPLE_ID" || -z "$APPLE_APP_PASSWORD" ]]; then
    fail "--store-password requires APPLE_ID and APPLE_APP_PASSWORD to be set."
    return
  fi

  if ! command_exists security; then
    fail "security is not available."
    return
  fi

  security add-generic-password -U -a "$APPLE_ID" -s "$KEYCHAIN_ITEM" -w "$APPLE_APP_PASSWORD"
  ok "Stored app-specific password in keychain item '$KEYCHAIN_ITEM'."
}

maybe_detect_provider_public_id() {
  [[ -z "$ASC_PROVIDER_PUBLIC_ID" ]] || return
  [[ -n "$APPLE_ID" ]] || return

  local -a cmd=(xcrun altool --list-providers --output-format json -u "$APPLE_ID")

  if [[ -n "$APPLE_APP_PASSWORD" ]]; then
    export APPLE_APP_PASSWORD
    cmd+=(-p "@env:APPLE_APP_PASSWORD")
  elif keychain_item_exists "$KEYCHAIN_ITEM"; then
    cmd+=(-p "@keychain:$KEYCHAIN_ITEM")
  else
    return
  fi

  local probe_file
  probe_file="$(mktemp -t void-providers.XXXXXX.json)"
  if "${cmd[@]}" > "$probe_file" 2>/dev/null; then
    ASC_PROVIDER_PUBLIC_ID="$(json_read_provider_id "$probe_file" "$TEAM_ID")"
  fi
  rm -f "$probe_file"
}

check_app_store_connect() {
  if [[ "$CHECK_ASC" -eq 0 ]]; then
    return
  fi

  section "App Store Connect Probe"

  if [[ -n "$APP_STORE_CONNECT_API_KEY_ID" || -n "$APP_STORE_CONNECT_API_ISSUER_ID" || -n "$APP_STORE_CONNECT_API_KEY_PATH" ]]; then
    if [[ -z "$APP_STORE_CONNECT_API_KEY_ID" || -z "$APP_STORE_CONNECT_API_ISSUER_ID" || -z "$APP_STORE_CONNECT_API_KEY_PATH" ]]; then
      fail "API key probe requires APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_API_ISSUER_ID, and APP_STORE_CONNECT_API_KEY_PATH."
      return
    fi

    if [[ ! -f "$APP_STORE_CONNECT_API_KEY_PATH" ]]; then
      fail "API key file not found: $APP_STORE_CONNECT_API_KEY_PATH"
      return
    fi

    export API_PRIVATE_KEYS_DIR
    API_PRIVATE_KEYS_DIR="$(dirname "$APP_STORE_CONNECT_API_KEY_PATH")"

    set +e
    local jwt_output token body_file http_code
    jwt_output="$(xcrun altool --generate-jwt --api-key "$APP_STORE_CONNECT_API_KEY_ID" --api-issuer "$APP_STORE_CONNECT_API_ISSUER_ID" --p8-file-path "$APP_STORE_CONNECT_API_KEY_PATH" 2>&1)"
    local jwt_status=$?
    set -e

    if [[ $jwt_status -ne 0 ]]; then
      fail "Failed to generate App Store Connect JWT from the API key."
      printf '%s\n' "$jwt_output"
      return
    fi

    token="$(printf '%s\n' "$jwt_output" | tail -n 1)"
    body_file="$(mktemp -t void-asc-probe.XXXXXX.json)"

    set +e
    http_code="$(curl -s -o "$body_file" -w '%{http_code}' -H "Authorization: Bearer $token" "https://api.appstoreconnect.apple.com/v1/apps?limit=1")"
    local curl_status=$?
    set -e

    if [[ $curl_status -ne 0 ]]; then
      fail "Failed to reach the App Store Connect API."
      rm -f "$body_file"
      return
    fi

    if [[ "$http_code" == "200" ]]; then
      ok "App Store Connect API key probe succeeded."
      rm -f "$body_file"
      return
    fi

    if grep -qi 'required agreement is missing or has expired\|required contracts' "$body_file"; then
      fail "Apple account is blocked by pending/expired agreements."
      info "Check https://appstoreconnect.apple.com/ and https://developer.apple.com/account/"
      rm -f "$body_file"
      return
    fi

    if grep -qi 'missing or invalid' "$body_file"; then
      fail "The detected App Store Connect API key did not authenticate successfully."
      info "The local ~/.xappstoreconnect config may be stale, revoked, or not valid for this workflow."
      rm -f "$body_file"
      return
    fi

    fail "App Store Connect API key probe failed with HTTP $http_code."
    cat "$body_file"
    rm -f "$body_file"
    return
  elif [[ -n "$APPLE_ID" ]]; then
    local -a cmd=(xcrun altool --list-providers --output-format json)

    if [[ -n "$APPLE_APP_PASSWORD" ]]; then
      export APPLE_APP_PASSWORD
      cmd+=(-u "$APPLE_ID" -p "@env:APPLE_APP_PASSWORD")
    elif keychain_item_exists "$KEYCHAIN_ITEM"; then
      cmd+=(-u "$APPLE_ID" -p "@keychain:$KEYCHAIN_ITEM")
    else
      fail "Need APPLE_APP_PASSWORD or keychain item '$KEYCHAIN_ITEM' for Apple ID probe."
      return
    fi
  else
    fail "No usable App Store Connect credentials available for probe."
    return
  fi

  set +e
  local output
  output="$(${cmd[@]} 2>&1)"
  local status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    ok "App Store Connect Apple ID probe succeeded."
    printf '%s\n' "$output"
    return
  fi

  if grep -qi 'required agreement is missing or has expired\|required contracts' <<<"$output"; then
    fail "Apple account is blocked by pending/expired agreements."
    info "Check https://appstoreconnect.apple.com/ and https://developer.apple.com/account/"
    return
  fi

  fail "App Store Connect Apple ID probe failed."
  printf '%s\n' "$output"
}

section "Project"
info "Project: $PROJECT_PATH"
info "Scheme: $SCHEME"
info "Team ID: $TEAM_ID"

maybe_import_xappstoreconnect
maybe_detect_provider_public_id

section "Local Credentials"

if [[ -n "$APPLE_ID" ]]; then
  ok "APPLE_ID is set in the current shell."
else
  warn "APPLE_ID is not set in the current shell."
fi

if [[ -n "$APPLE_APP_PASSWORD" ]]; then
  ok "APPLE_APP_PASSWORD is set in the current shell."
else
  warn "APPLE_APP_PASSWORD is not set in the current shell."
fi

if keychain_item_exists "$KEYCHAIN_ITEM"; then
  ok "Keychain item '$KEYCHAIN_ITEM' exists."
else
  warn "Keychain item '$KEYCHAIN_ITEM' was not found."
fi

if keychain_item_exists "AC_PASSWORD"; then
  ok "Keychain item 'AC_PASSWORD' exists."
else
  warn "Keychain item 'AC_PASSWORD' was not found."
fi

mapfile -t FOUND_KEYS < <(find_api_keys | sort -u)
if [[ ${#FOUND_KEYS[@]} -gt 0 ]]; then
  ok "Found App Store Connect private keys:"
  for key in "${FOUND_KEYS[@]}"; do
    printf '  - %s\n' "$key"
  done
else
  warn "No AuthKey_*.p8 files found in the standard private key directories."
fi

if [[ -f "$XAPPSTORECONNECT_PATH" ]]; then
  ok "Found local App Store Connect config at $XAPPSTORECONNECT_PATH"
else
  warn "Local App Store Connect config $XAPPSTORECONNECT_PATH was not found."
fi

if [[ -n "$APP_STORE_CONNECT_API_KEY_ID" ]]; then
  ok "APP_STORE_CONNECT_API_KEY_ID is set in the current shell."
else
  warn "APP_STORE_CONNECT_API_KEY_ID is not set in the current shell."
fi

if [[ -n "$APP_STORE_CONNECT_API_ISSUER_ID" ]]; then
  ok "APP_STORE_CONNECT_API_ISSUER_ID is set in the current shell."
else
  warn "APP_STORE_CONNECT_API_ISSUER_ID is not set in the current shell."
fi

if [[ -n "$APP_STORE_CONNECT_API_KEY_PATH" ]]; then
  if [[ -f "$APP_STORE_CONNECT_API_KEY_PATH" ]]; then
    ok "APP_STORE_CONNECT_API_KEY_PATH points to an existing file."
  else
    fail "APP_STORE_CONNECT_API_KEY_PATH is set but the file does not exist."
  fi
else
  warn "APP_STORE_CONNECT_API_KEY_PATH is not set in the current shell."
fi

if [[ -n "$ASC_PROVIDER_PUBLIC_ID" ]]; then
  ok "Detected App Store Connect provider public ID for team $TEAM_ID."
else
  warn "Could not detect App Store Connect provider public ID yet."
fi

store_password_if_requested

section "Tooling"

if command_exists xcodebuild; then
  ok "xcodebuild is available."
  xcodebuild -version
else
  fail "xcodebuild is not available."
fi

if command_exists xcrun; then
  ok "xcrun is available."
else
  fail "xcrun is not available."
fi

if command_exists xcodebuild; then
  local_sdks="$(xcodebuild -showsdks 2>/dev/null || true)"
  if grep -q 'iOS 26\.4' <<<"$local_sdks"; then
    ok "Xcode reports iOS SDKs are installed."
  else
    warn "Could not confirm the expected iOS SDK install from xcodebuild -showsdks."
  fi
fi

section "Recommended Next Steps"
printf '1. If you want Apple ID auth, run:\n'
printf '   export APPLE_ID="you@example.com"\n'
printf '   export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"\n'
printf '   scripts/setup-testflight.sh --store-password\n'
printf '2. If you want API key auth, export:\n'
printf '   APP_STORE_CONNECT_API_KEY_ID\n'
printf '   APP_STORE_CONNECT_API_ISSUER_ID\n'
printf '   APP_STORE_CONNECT_API_KEY_PATH\n'
printf '   ASC_PROVIDER_PUBLIC_ID (optional; script auto-detects it from TEAM_ID when possible)\n'
printf '3. Probe App Store Connect auth with:\n'
printf '   scripts/setup-testflight.sh --check-asc\n'
printf '4. Build an archive locally with:\n'
printf '   scripts/testflight.sh --archive-only\n'
printf '5. Upload to TestFlight with:\n'
printf '   scripts/testflight.sh\n'

check_app_store_connect
