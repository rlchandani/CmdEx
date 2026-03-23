---
paths:
  - "CmdExCore/Sources/CmdExCore/Logic/**/*.swift"
---

# Dependency Client Rules

- Clients use `@DependencyClient` macro with `Sendable` conformance
- Live implementations are actors or use explicit synchronization
- Client struct has closure properties, live implementation is a separate actor/class
- Register via `DependencyKey` with `liveValue`
- Access in features via `@Dependency(\.clientName)`
- Error handling: log errors via `SBLog`, don't silently swallow with `try?` unless
  the failure is truly expected and harmless
