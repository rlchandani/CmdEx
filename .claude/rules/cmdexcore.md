---
paths:
  - "CmdExCore/**/*.swift"
---

# CmdExCore Rules

- CmdExCore is a Swift Package — no AppKit/SwiftUI imports allowed
- All types must be `Sendable` (strict concurrency)
- Use `SBLog` for logging, not `print()`
- `@unchecked Sendable` requires a justification comment explaining why it's safe
- `nonisolated(unsafe)` requires a comment explaining the safety invariant
- Codable implementations must handle missing keys gracefully (backward compatibility)
- Tests use Swift Testing framework (`@Test`, `#expect`, `@Suite`)
