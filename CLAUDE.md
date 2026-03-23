# CmdEx – Dev Notes for Agents

This file provides guidance for coding agents working in this repo.

## Project Overview

CmdEx is a macOS menu bar shortcut manager. Users launch apps, run shell commands, open URLs, and manage developer workflows from a single popover triggered by ⌘⇧K.

## Build & Development Commands

```bash
# Generate the Xcode project (required before building)
xcodegen generate

# Build the app
xcodebuild -project CmdEx.xcodeproj -scheme CmdEx -configuration Debug build -skipMacroValidation

# Run tests (must be run from CmdExCore directory)
cd CmdExCore && swift test

# Open in Xcode (recommended for development)
xcodegen generate && open CmdEx.xcodeproj
```

## Architecture

The app uses **The Composable Architecture (TCA)** for state management. Key architectural components:

### Features (TCA Reducers)
- `AppFeature`: Root feature coordinating the app lifecycle
- `ShortcutsFeature`: Shortcuts CRUD, execution, import/export, recent history

### Dependency Clients
- `ExecutorClient`: Runs shell commands, opens apps/URLs/files, launches editors
- `PersistenceClient`: JSON file storage for shortcuts and settings
- `PermissionClient`: macOS permission checking (Accessibility, Automation, Full Disk Access)
- `ScreenshotClient`: Watches for new screenshots and copies paths to clipboard
- `ToastClient`: Non-intrusive HUD toast notifications
- `ClipboardClient`: Clipboard read/write operations

### Key Dependencies
- **Swift Composable Architecture**: State management
- **Sparkle**: Auto-updates (feed: GitHub Releases appcast.xml)

## Important Implementation Details

1. **XcodeGen**: The `.xcodeproj` is generated from `project.yml` — never edit the Xcode project directly. Always run `xcodegen generate` after changing `project.yml`.

2. **Menu Bar Icon**: Uses a custom template image `MenuBarIcon` from the asset catalog (not an SF Symbol). Set as `isTemplate = true` so macOS adapts it for light/dark mode.

3. **Global Hotkey**: ⌘⇧K registered via `NSEvent.addGlobalMonitorForEvents` (requires Accessibility permission). Also registers a local monitor for when the app is focused.

4. **Placeholder Parameters**: Shortcuts can contain `{paramName}` placeholders. When executed, an `NSAlert` prompts for values. Last-used values are persisted per-shortcut.

5. **Permission Polling**: The app checks permission status every 3 seconds and shows a warning banner when any are missing.

6. **Flash Icon on Execute**: After running a shortcut, the menu bar icon briefly changes to a checkmark for visual feedback.

7. **Screenshot Watcher**: Uses FSEvents to monitor the Desktop for new screenshots, copying the path to clipboard automatically.

8. **Time Converter**: A floating panel that shows the current time across configured time zones with a day offset indicator.

9. **Settings Storage**: Uses `@Shared(.appSettings)` with file storage — no UserDefaults. Settings are stored as JSON in Application Support.

10. **Toast Notifications**: Custom `NSWindow`-based HUD that appears briefly for non-intrusive feedback (e.g., "Copied to clipboard").

## Git Commit Messages

- Use a concise, descriptive subject line (50–70 characters)
- Follow conventional commits: `feat:`, `fix:`, `chore:`, `docs:`
- Include context in the body when needed
- **Do NOT include `Co-Authored-By` trailers** in commit messages

## Version Bumping

Update the version in `project.yml`:
1. `MARKETING_VERSION` → `"X.Y.0"`
2. `CURRENT_PROJECT_VERSION` → increment

Also update the version badge in `README.md`.

Commit with: `chore: bump version to X.Y.0`
