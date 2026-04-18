# AGENTS.md

## TestFlight Release

This repo has a local TestFlight flow using:

- `scripts/setup-testflight.sh`
- `scripts/testflight.sh`

Normal usage:

```bash
APPLE_ID="you@example.com" scripts/testflight.sh
```

That assumes the app-specific password is already stored in the keychain item named by `APPLE_APP_PASSWORD_KEYCHAIN_ITEM`.

## Secrets Policy

- Never commit Apple passwords, app-specific passwords, App Store Connect provider UUIDs, or API private keys.
- Never hardcode personal Apple IDs in committed repo files.
- Secrets must come from environment variables, macOS keychain, or 1Password `op://` references.
- If using 1Password, prefer:

```bash
export APPLE_ID="you@example.com"
export APPLE_APP_PASSWORD='op://Personal/Apple App-Specific Password (TestFlight)/password'
op run -- scripts/testflight.sh
```

- If using keychain, store once and then reuse:

```bash
security add-generic-password -U -a "$APPLE_ID" -s "VOID_APPSTORE" -w "$APPLE_APP_PASSWORD"
APPLE_ID="you@example.com" APPLE_APP_PASSWORD_KEYCHAIN_ITEM="VOID_APPSTORE" scripts/testflight.sh
```

## Provider Detection

- `scripts/testflight.sh` auto-detects the App Store Connect provider using `TEAM_ID` and authenticated `altool --list-providers` output.
- Do not commit provider UUIDs to repo files unless there is a strong reason.

## Safety Checks Before Commit

- Grep changed files for accidental Apple IDs, passwords, private key material, and `op://` expansions.
- Keep docs/examples generic: use `you@example.com`, `xxxx-xxxx-xxxx-xxxx`, and `op://...` placeholders.
