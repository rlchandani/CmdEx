# CmdEx

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
- `@Dependency` clients: `ExecutorClient`, `PersistenceClient`, `ScreenshotClient`, `ToastClient`
- `@Shared(.appSettings)` file storage — no UserDefaults
- `IdentifiedArrayOf` for shortcuts and groups
- Semantic typography and accessibility labels throughout

## Requirements

- macOS 15.0+
- Xcode 16+
- Swift 6.0

## Build

```bash
xcodegen generate
xcodebuild -project CmdEx.xcodeproj -scheme CmdEx -configuration Debug build -skipMacroValidation
```

## Test

```bash
cd CmdExCore && swift test
```

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
