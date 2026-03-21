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

## License

MIT

## Author

[Rohit Chandani](https://rlchandani.dev/)
