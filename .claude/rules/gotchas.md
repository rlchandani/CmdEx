# Gotchas & Hard-Won Debugging Insights

## Xcode / Build

- **XcodeGen required**: The `.xcodeproj` is generated from `project.yml`. Never edit the
  Xcode project directly. Always run `xcodegen generate` after changing `project.yml`.

- **Working directory for xcodebuild**: Must run from project root. If CWD is
  CmdExCore, xcodebuild tries to build the SPM package instead.

- **-skipMacroValidation**: Required for CLI builds because TCA and its dependencies
  use Swift macros. Xcode GUI trusts them automatically.

## macOS Permissions

- **Accessibility required for hotkey**: The global ⌘⇧K monitor won't fire without
  Accessibility permission. The local monitor still works when the app is focused.

- **Automation permission**: Required for sending AppleScript commands to Terminal/iTerm2.
  macOS prompts automatically on first use — no need to request proactively.

- **Stale TCC entries**: When app code signature changes (common during dev), old TCC
  entries may be present but non-functional. The Developer window offers tccutil reset.

## TCA / SwiftUI

- **Capturing state in .run closures**: Always capture specific values
  (`let selected = state.selectedShortcut`) before the `.run` block, never
  capture `[state]` — it copies the entire state at that point in time.

## Menu Bar

- **Template images**: Menu bar icons must be set as `isTemplate = true` so macOS
  renders them correctly in both light and dark mode.

- **Flash icon**: After executing a shortcut, the icon briefly changes to a checkmark.
  The original image is captured before the swap.

- **LSUIElement**: The app runs as an agent (no Dock icon) via `LSUIElement = true`
  in Info.plist. This means no main menu bar — all interaction through the status item.
