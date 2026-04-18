# TestFlight Release

This repo now includes a local TestFlight script built around `xcodebuild` and `xcrun altool`.

Start with the audit/setup helper:

```bash
scripts/setup-testflight.sh
```

That command searches the standard local key locations, checks likely keychain items, confirms tool availability, and prints the next steps to finish setup.

## Best current plan

Based on current Apple guidance and tool support:

1. Use `xcodebuild archive` to create a signed iOS archive.
2. Use `xcodebuild -exportArchive` with `method=app-store-connect` to produce the `.ipa`.
3. Upload the `.ipa` with `xcrun altool`.
4. Prefer a **team App Store Connect API key** for automation.
5. Fall back to **Apple ID + app-specific password** for local uploads when needed.
6. After the local flow works, automate the same script in CI.

## Script

```bash
scripts/testflight.sh --help
```

## Guided Setup

```bash
scripts/setup-testflight.sh --help
```

Examples:

```bash
scripts/setup-testflight.sh
APPLE_ID=you@example.com APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx scripts/setup-testflight.sh --store-password
scripts/setup-testflight.sh --check-asc
```

You can also keep the password in 1Password and inject it with `op`:

```bash
export APPLE_ID="you@example.com"
export APPLE_APP_PASSWORD='op://Personal/Apple App-Specific Password (TestFlight)/password'
op run -- scripts/testflight.sh
```

### Archive only

Build the archive and `.ipa` without uploading:

```bash
scripts/testflight.sh --archive-only
```

### Upload with Apple ID

```bash
export APPLE_ID="you@example.com"
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
scripts/testflight.sh
```

Or store the password in your keychain once:

```bash
export APPLE_ID="you@example.com"
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
security add-generic-password -U -a "$APPLE_ID" -s "VOID_APPSTORE" -w "$APPLE_APP_PASSWORD"
APPLE_APP_PASSWORD_KEYCHAIN_ITEM=VOID_APPSTORE scripts/testflight.sh
```

The script auto-detects the App Store Connect provider from `TEAM_ID`, so you do not need to commit or remember a provider UUID.

### Upload with App Store Connect API key

Apple's current automation direction is App Store Connect API keys, but use a **team key**, not an individual key.

```bash
export APP_STORE_CONNECT_API_KEY_ID="XXXXXXXXXX"
export APP_STORE_CONNECT_API_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"
scripts/testflight.sh
```

## Overrides

```bash
scripts/testflight.sh --version 1.1.1 --build-number 101
```

By default the script uses a timestamp build number so TestFlight uploads do not collide.

## Outputs

Artifacts land under:

```bash
build/testflight/
```

Including:

- `*.xcarchive`
- `export-<build-number>/Void.ipa`

## Next Time

With the keychain item stored, the normal one-command flow is:

```bash
APPLE_ID="you@example.com" scripts/testflight.sh
```

Or, if you prefer 1Password over keychain:

```bash
export APPLE_ID="you@example.com"
export APPLE_APP_PASSWORD='op://Personal/Apple App-Specific Password (TestFlight)/password'
op run -- scripts/testflight.sh
```
