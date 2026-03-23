# CmdEx — Shortcut Bar

[![Release](https://github.com/rlchandani/CmdEx/actions/workflows/release.yml/badge.svg)](https://github.com/rlchandani/CmdEx/actions/workflows/release.yml)
[![Version](https://img.shields.io/badge/version-1.5.0-green)](https://github.com/rlchandani/CmdEx/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/rlchandani/CmdEx/total)](https://github.com/rlchandani/CmdEx/releases)
[![License](https://img.shields.io/badge/license-MIT-blue)](https://github.com/rlchandani/CmdEx/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-blue)]()
[![Swift](https://img.shields.io/badge/Swift-6.0-orange)]()

A macOS menu bar shortcut manager. Launch apps, run shell commands, open URLs, and manage developer workflows — all from a single popover.

## Features

- **Menu bar popover** with search, grouped shortcuts, and recent history
- **Command types**: app, shell, terminal, URL, file/folder, editor
- **Placeholder parameters** with last-used memory
- **Screenshot watcher** — copies new screenshot paths to clipboard
- **Time converter** — floating panel with day offset indicator
- **Toast notifications** — non-intrusive HUD alerts
- **Settings** — default apps, time zones, export/import, launch at login
- **Sparkle auto-updates** — in-app update notifications

## Setup

On first launch, CmdEx will:
1. Appear in your menu bar (no Dock icon by default)
2. Prompt for **Accessibility** permission (required for the global hotkey ⌘⇧K)
3. Additional permissions (Automation, Full Disk Access) are requested as needed

Press **⌘⇧K** from any app to open the popover, or click the menu bar icon.

## Architecture

Built with [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) (TCA) and Swift 6 strict concurrency.

- `AppFeature` → `ShortcutsFeature` via `Scope`
- `@Dependency` clients: `ExecutorClient`, `PersistenceClient`, `PermissionClient`, `ScreenshotClient`, `ToastClient`, `ClipboardClient`
- `@Shared(.appSettings)` file storage — no UserDefaults
- `IdentifiedArrayOf` for shortcuts and groups
- Semantic typography and accessibility labels throughout

## Requirements

- macOS 15.0+
- Xcode 16+
- Swift 6.0
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Development

### Building

Open in Xcode (recommended):

```bash
xcodegen generate
open CmdEx.xcodeproj
```

Or build from the command line:

```bash
xcodegen generate
xcodebuild -project CmdEx.xcodeproj -scheme CmdEx -configuration Debug build -skipMacroValidation
```

`-skipMacroValidation` is required because several SPM dependencies (TCA, swift-dependencies, swift-case-paths, swift-perception) use Swift macros. Xcode trusts them automatically via its UI; the CLI requires the flag.

### Testing

```bash
cd CmdExCore && swift test
```

Tests live in `CmdExCore/Tests/CmdExCoreTests/` and cover models, reducers, dependency clients, and feature logic. All tests use Swift Testing (`@Test`, `#expect`) — no XCTest.

### Code Signing

The project uses `CODE_SIGN_STYLE = Automatic`. Debug builds sign with "Apple Development" — make sure you have a valid Apple Development certificate in your keychain and your team is selected in Xcode's Signing & Capabilities tab.

- The `project.yml` has `DEVELOPMENT_TEAM` and `CODE_SIGN_STYLE = Automatic` pre-configured. Do **not** pass `DEVELOPMENT_TEAM` or `CODE_SIGN_IDENTITY` on the xcodebuild command line — this overrides the project settings and breaks SPM macro plugin signing.
- CLI builds use `-skipMacroValidation` to bypass the macro trust prompt (which only works in Xcode GUI).
- GitHub Actions CI also uses `-skipMacroValidation` and handles signing via an imported certificate.

## Project Structure

```
CmdEx/                          # App target (SwiftUI views, AppKit integration)
  App/                          # AppDelegate, MenuBarManager, PopoverManager, ToastWindow, etc.
  Features/                     # Views: Dashboard, Preferences, DeveloperWindow, etc.
  Assets.xcassets/              # App icon and menu bar icon
CmdExCore/                      # Swift package (testable core logic)
  Sources/CmdExCore/
    AppFeature.swift            # Root TCA reducer
    ShortcutsFeature.swift      # Shortcuts CRUD, execution, import/export
    Models/                     # Shortcut, ShortcutGroup, AppSettings, etc.
    Logic/                      # Dependency clients (Executor, Persistence, Permission, etc.)
  Tests/CmdExCoreTests/         # All tests
project.yml                     # XcodeGen spec (source of truth for project config)
```

## Permissions

| Permission | Why | How to grant |
|---|---|---|
| **Accessibility** | Global hotkey (⌘⇧K) | System Settings → Privacy & Security → Accessibility → toggle CmdEx on |
| **Automation** | Send commands to Terminal/iTerm2 via AppleScript | Run a terminal shortcut once — macOS prompts automatically |
| **Full Disk Access** | Shell commands accessing protected paths | System Settings → Privacy & Security → Full Disk Access → add CmdEx |

The app checks permission status every 3 seconds and shows a warning banner when any are missing, with a "Fix" button that navigates to the Permissions section.

### Resetting permissions (developer)

Reset individual services — **never use `tccutil reset All`** as it can freeze macOS:

```bash
tccutil reset Accessibility com.cmdex.app && \
tccutil reset AppleEvents com.cmdex.app && \
tccutil reset ListenEvent com.cmdex.app && \
tccutil reset SystemPolicyAllFiles com.cmdex.app
```

There's also a hidden Developer window (tap the version number 7 times in Settings → About) with a "Copy Command" button that generates the correct reset + relaunch command for the current build.

## Releasing

Releases are automated via GitHub Actions. Bump the version, push to `main`, and the workflow handles the rest.

### How to release

1. Bump `MARKETING_VERSION` in `project.yml`:
   ```yaml
   MARKETING_VERSION: "1.5.0"
   ```
2. Bump `CURRENT_PROJECT_VERSION` if needed:
   ```yaml
   CURRENT_PROJECT_VERSION: "6"
   ```
3. Commit and push:
   ```bash
   git add -A && git commit -m "chore: bump version to 1.5.0"
   git push origin main
   ```
4. GitHub Actions automatically:
   - Detects the version bump (compares against existing tags)
   - Builds a Release archive on macOS
   - Zips and signs the `.app` with Sparkle EdDSA
   - Generates `appcast.xml`
   - Creates a GitHub Release (`v1.5.0`) with the zip and appcast

Users running CmdEx are notified of the update via Sparkle and can install it with one click.

### Setup (one-time)

Set the `SPARKLE_PRIVATE_KEY` GitHub secret for Sparkle update signing:

```bash
generate_keys -x /tmp/sparkle_key.txt
gh secret set SPARKLE_PRIVATE_KEY < /tmp/sparkle_key.txt
rm /tmp/sparkle_key.txt
```

### Manual release

```bash
# Build
xcodegen generate
xcodebuild -project CmdEx.xcodeproj -scheme CmdEx -configuration Release archive \
  -archivePath ./build/CmdEx.xcarchive -skipMacroValidation

# Package
cp -R ./build/CmdEx.xcarchive/Products/Applications/CmdEx.app ./build/CmdEx.app
ditto -c -k --keepParent ./build/CmdEx.app ./build/CmdEx-1.5.0.zip

# Sign (prints edSignature and length for appcast.xml)
sign_update ./build/CmdEx-1.5.0.zip

# Create release
gh release create v1.5.0 ./build/CmdEx-1.5.0.zip ./build/appcast.xml \
  --title "v1.5.0" --generate-notes
```

### Debugging CI failures

List recent workflow runs:
```bash
gh run list --repo rlchandani/CmdEx --limit 10
```

View a specific failed run (use the run ID from the list):
```bash
gh run view <RUN_ID> --repo rlchandani/CmdEx
```

Find the failed job ID:
```bash
gh run view <RUN_ID> --repo rlchandani/CmdEx --json jobs --jq '.jobs[] | "\(.databaseId) \(.name) \(.conclusion)"'
```

Get the failed job's logs:
```bash
gh run view --log-failed --job=<JOB_ID> --repo rlchandani/CmdEx
```

Common failures:
- **"No signing certificate found"** — `MACOS_CERTIFICATE` secret is missing or the `.p12` is invalid.
- **"failed downloading Sparkle"** — stale SPM cache on CI runner. The workflow clears it automatically.
- **"Library Validation failed"** — app and frameworks signed with different identities. Ensure `DEVELOPMENT_TEAM` is set in `project.yml`.

## License

MIT — see [LICENSE](LICENSE) for details.

## Author

[Rohit Chandani](https://rlchandani.dev/)
