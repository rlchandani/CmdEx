# Pre-Production Code Review — CmdEx-Specific

## Permissions & TCC

- Every operation that requires a permission must check status BEFORE attempting
- AppleScript commands must use hardcoded app names, never user input
- No user-controlled strings should reach `Process.arguments`
- Permission polling must not create duplicate effects

## Command Execution

- Shell commands run via `Process()` — verify proper quoting and escaping
- Placeholder resolution must use `resolvedCommandShellEscaped(with:)` for
  shell/terminal types to prevent injection
- URL commands must validate the URL before opening
- File/folder commands must verify path exists before opening

## Menu Bar App Specifics

- NSStatusItem handles menu bar overflow gracefully
- Popover dismissal cleans up any pending state
- Global hotkey monitor cleaned up in deinit

## Settings & Persistence

- New AppSettings fields must have default values for backward compatibility
- Import/export must validate JSON structure before applying
- No secrets stored in plaintext — use Keychain if needed

## Sparkle Updates

- `SUFeedURL` must use HTTPS
- `SUPublicEDKey` must be present for EdDSA verification
