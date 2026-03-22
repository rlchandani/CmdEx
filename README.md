# CmdEx

[![Download Latest Release](https://img.shields.io/github/v/release/rlchandani/CmdEx?label=Download&sort=semver)](https://github.com/rlchandani/CmdEx/releases/latest)

A macOS menu bar shortcut manager. Launch apps, run shell commands, open URLs, and manage developer workflows — all from a single popover.

## Features

- **Menu bar popover** with search, grouped shortcuts, and recent history
- **Command types**: app, shell, terminal, URL, file/folder, editor
- **Placeholder parameters** with last-used memory
- **Screenshot watcher** — copies new screenshot paths to clipboard
- **Time converter** — floating panel with day offset indicator
- **Toast notifications** — non-intrusive HUD alerts
- **Settings** — default apps, time zones, export/import, launch at login

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

## Development Setup

### First-time setup

1. **Install XcodeGen** (generates the `.xcodeproj` from `project.yml`):
   ```bash
   brew install xcodegen
   ```

2. **Generate the Xcode project**:
   ```bash
   xcodegen generate
   ```

3. **Trust SPM macro plugins** — Open the project in Xcode once and build (⌘B). Xcode will prompt you to trust macro plugins from swift-composable-architecture, swift-case-paths, swift-dependencies, swift-perception, and swift-sharing. Click "Trust & Enable" for each. This is a one-time step persisted in your local Xcode settings.

4. **Code signing** — The project uses `CODE_SIGN_STYLE = Automatic` with the development team configured in `project.pbxproj`. Xcode resolves the signing identity automatically. No manual certificate setup is needed beyond having an Apple Developer account signed in to Xcode (Settings → Accounts).

### Signing notes

- The `project.pbxproj` has `DEVELOPMENT_TEAM` and `CODE_SIGN_STYLE = Automatic` pre-configured. Do **not** pass `DEVELOPMENT_TEAM` or `CODE_SIGN_IDENTITY` on the xcodebuild command line — this overrides the project settings and breaks SPM macro plugin signing.
- CLI builds use `-skipMacroValidation` to bypass the macro trust prompt (which only works in Xcode GUI).
- GitHub Actions CI also uses `-skipMacroValidation` and handles signing separately for distribution.

## Build

```bash
xcodegen generate
xcodebuild -project CmdEx.xcodeproj -scheme CmdEx -configuration Debug build -skipMacroValidation
```

The built app is at:
```
~/Library/Developer/Xcode/DerivedData/CmdEx-*/Build/Products/Debug/CmdEx.app
```

To run it:
```bash
open ~/Library/Developer/Xcode/DerivedData/CmdEx-*/Build/Products/Debug/CmdEx.app
```

## Test

```bash
cd CmdExCore && swift test
```

Tests live in `CmdExCore/Tests/CmdExCoreTests/` and cover models, reducers, dependency clients, and feature logic. All tests use Swift Testing (`@Test`, `#expect`) — no XCTest.

## Project Structure

```
CmdEx/                          # App target (SwiftUI views, AppKit integration)
  App/                          # AppDelegate, MenuBarManager, PopoverManager, etc.
  Features/                     # Views: Dashboard, Preferences, About, etc.
CmdExCore/                      # Swift package (testable core logic)
  Sources/CmdExCore/
    AppFeature.swift            # Root TCA reducer
    ShortcutsFeature.swift      # Shortcuts CRUD, execution, import/export
    Models/                     # Shortcut, ShortcutGroup, AppSettings, etc.
    Logic/                      # Dependency clients (Executor, Persistence, etc.)
  Tests/CmdExCoreTests/         # All tests
project.yml                     # XcodeGen spec (source of truth for project config)
```

## Permissions

CmdEx requires these macOS permissions to function:

| Permission | Why | How to grant |
|---|---|---|
| **Accessibility** | Global hotkey (⌘⇧K) | System Settings → Privacy & Security → Accessibility → toggle CmdEx on |
| **Automation** | Send commands to Terminal/iTerm2 via AppleScript | Run a terminal shortcut once — macOS prompts automatically |
| **Full Disk Access** | Shell commands accessing protected paths | System Settings → Privacy & Security → Full Disk Access → add CmdEx |

The app checks permission status every 3 seconds and shows a warning banner when any are missing.

### Resetting permissions (developer)

There's a hidden Developer window accessible by tapping the version number 7 times in the About tab. It has a "Copy Command" button that copies a Terminal command to reset all TCC permissions and relaunch the app. Useful when testing the permission grant flow.

## Releasing New Versions

Releases are automated via GitHub Actions. When you push to `main` with a new version number, the workflow builds, signs, and publishes a GitHub Release automatically.

### How to release

1. Bump `MARKETING_VERSION` in `project.yml`:
   ```yaml
   MARKETING_VERSION: "1.1.0"
   ```
2. Bump `CURRENT_PROJECT_VERSION` if needed:
   ```yaml
   CURRENT_PROJECT_VERSION: "2"
   ```
3. Commit and push:
   ```bash
   git add -A && git commit -m "chore: bump version to 1.1.0"
   git push origin main
   ```
4. GitHub Actions automatically:
   - Detects the version bump (compares against existing tags)
   - Builds a Release archive on macOS
   - Zips and signs the `.app` with Sparkle EdDSA
   - Generates `appcast.xml`
   - Creates a GitHub Release (`v1.1.0`) with the zip and appcast

Users running CmdEx are notified of the update via Sparkle and can install it with one click.

### Setup (one-time)

The `SPARKLE_PRIVATE_KEY` GitHub secret must be set for signing. To export your key:

```bash
# From the Sparkle bin in DerivedData:
generate_keys -x /tmp/sparkle_key.txt
gh secret set SPARKLE_PRIVATE_KEY < /tmp/sparkle_key.txt
rm /tmp/sparkle_key.txt
```

### Manual release

If you need to release manually without the workflow:

```bash
# Build
xcodegen generate
xcodebuild -project CmdEx.xcodeproj -scheme CmdEx -configuration Release archive \
  -archivePath ./build/CmdEx.xcarchive -skipMacroValidation

# Package
cp -R ./build/CmdEx.xcarchive/Products/Applications/CmdEx.app ./build/CmdEx.app
ditto -c -k --keepParent ./build/CmdEx.app ./build/CmdEx-1.1.0.zip

# Sign (prints edSignature and length for appcast.xml)
sign_update ./build/CmdEx-1.1.0.zip

# Create release
gh release create v1.1.0 ./build/CmdEx-1.1.0.zip ./build/appcast.xml \
  --title "v1.1.0" --generate-notes
```

## License

MIT

## Author

[Rohit Chandani](https://rlchandani.dev/)
