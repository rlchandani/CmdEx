---
paths:
  - "CmdEx/Features/**/*.swift"
  - "CmdExCore/Sources/CmdExCore/*Feature.swift"
---

# TCA Feature Rules

- Every feature uses `@Reducer` macro with `@ObservableState` struct for State
- Use `@Dependency` for all client access — never instantiate clients directly
- Long-running effects must use `CancelID` enum and `.cancellable(id:)`
- Capture specific values before `.run` closures, never `[state]`
- Side effects belong in `.run` blocks, never in the reducer's synchronous path
- Use `@Shared` for cross-feature state (appSettings)
- Use `$shared.withLock { }` to mutate shared state
- Child features are composed via `Scope(state:action:)`
- Actions that only set state return `.none`
- Use `BindingReducer()` when the feature has `BindableAction`
