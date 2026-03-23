---
paths:
  - "CmdEx/Features/**/*View.swift"
  - "CmdEx/App/**/*View.swift"
---

# SwiftUI View Rules

- Views take `StoreOf<Feature>` via `@Bindable var store`
- Use `store.scope(state:action:)` to pass child stores
- Use `$store.property` for bindings to TCA state
- Keep `body` lightweight — move heavy computation to the reducer
- Avoid force unwraps in views — use `guard let` or `if let`
- Log errors in catch blocks — never use empty `catch {}`
