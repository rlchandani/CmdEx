import ComposableArchitecture
import Foundation

/// Owns shortcuts CRUD, groups, reordering, and execution.
@Reducer
public struct ShortcutsFeature {
    @ObservableState
    public struct State: Equatable {
        public var shortcuts: IdentifiedArrayOf<Shortcut> = []
        public var groups: IdentifiedArrayOf<ShortcutGroup> = []
        public var lastUsedValues: [String: [String: String]] = [:]
        public var recentIds: [Shortcut.ID] = []
        public var isLoading = false
        @Shared(.appSettings) public var settings: AppSettings

        public init() {}

        public var recentShortcuts: [Shortcut] {
            recentIds.compactMap { shortcuts[id: $0] }.prefix(3).map { $0 }
        }
    }

    public enum Action {
        // Data
        case loadData
        case dataLoaded(StoreData)

        // Shortcuts CRUD
        case addShortcut(Shortcut)
        case updateShortcut(Shortcut)
        case deleteShortcut(Shortcut.ID)
        case moveShortcuts(IndexSet, Int, ShortcutGroup.ID?)

        // Groups CRUD
        case addGroup(ShortcutGroup)
        case updateGroup(ShortcutGroup)
        case deleteGroup(ShortcutGroup.ID)
        case moveGroups(IndexSet, Int)

        // Execution
        case executeShortcut(Shortcut, resolvedCommand: String)
        case executionCompleted(ExecutionResult)

        // Placeholder values
        case saveLastUsed(Shortcut.ID, [String: String])

        // Tools
        case toggleDisableAll
        case exportJSON
        case toggleScreenshotWatcher
        case screenshotDetected(path: String)

        // Import/Export to file
        case importFromFile(URL)
        case importCompleted(StoreData)
        case exportToFile(URL)
    }

    @Dependency(\.persistence) var persistence
    @Dependency(\.executor) var executor
    @Dependency(\.toast) var toast
    @Dependency(\.screenshotClient) var screenshotClient
    @Dependency(\.clipboard) var clipboard

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadData:
                state.isLoading = true
                return .run { [persistence] send in
                    let data = try await persistence.load()
                    await send(.dataLoaded(data))
                }

            case let .dataLoaded(data):
                state.isLoading = false
                state.shortcuts = IdentifiedArray(uniqueElements: data.shortcuts)
                state.groups = IdentifiedArray(uniqueElements: data.groups)
                state.lastUsedValues = data.lastUsedValues
                return .none

            // MARK: - Shortcuts CRUD

            case let .addShortcut(shortcut):
                var s = shortcut
                s.sortOrder = (state.shortcuts.map(\.sortOrder).max() ?? -1) + 1
                state.shortcuts.append(s)
                return save(state)

            case let .updateShortcut(shortcut):
                state.shortcuts[id: shortcut.id] = shortcut
                return save(state)

            case let .deleteShortcut(id):
                state.shortcuts.remove(id: id)
                return save(state)

            case let .moveShortcuts(source, destination, groupId):
                var filtered = state.shortcuts
                    .filter { $0.groupId == groupId }
                    .sorted { $0.sortOrder < $1.sortOrder }
                filtered.move(fromOffsets: source, toOffset: destination)
                for (i, s) in filtered.enumerated() {
                    state.shortcuts[id: s.id]?.sortOrder = i
                }
                return save(state)

            // MARK: - Groups CRUD

            case let .addGroup(group):
                var g = group
                g.sortOrder = (state.groups.map(\.sortOrder).max() ?? -1) + 1
                state.groups.append(g)
                return save(state)

            case let .updateGroup(group):
                state.groups[id: group.id] = group
                return save(state)

            case let .deleteGroup(id):
                for i in state.shortcuts.indices where state.shortcuts[i].groupId == id {
                    state.shortcuts[i].groupId = nil
                }
                state.groups.remove(id: id)
                return save(state)

            case let .moveGroups(source, destination):
                var sorted = state.groups.sorted { $0.sortOrder < $1.sortOrder }
                sorted.move(fromOffsets: source, toOffset: destination)
                for (i, g) in sorted.enumerated() {
                    state.groups[id: g.id]?.sortOrder = i
                }
                return save(state)

            // MARK: - Execution

            case let .executeShortcut(shortcut, resolvedCommand):
                state.recentIds.removeAll { $0 == shortcut.id }
                state.recentIds.insert(shortcut.id, at: 0)
                if state.recentIds.count > 5 { state.recentIds = Array(state.recentIds.prefix(5)) }

                let browser = state.settings.preferredBrowser
                let terminal = state.settings.preferredTerminal
                let editor = state.settings.preferredEditor
                return .run { [executor] send in
                    let result: ExecutionResult
                    switch shortcut.commandType {
                    case .app:
                        result = await executor.executeApp(resolvedCommand)
                    case .url:
                        result = browser.isEmpty
                            ? await executor.executeURL(resolvedCommand)
                            : await executor.executeURLInBrowser(resolvedCommand, browser)
                    case .fileOrFolder:
                        result = await executor.executeFileOrFolder(resolvedCommand)
                    case .shell:
                        result = await executor.executeShell(resolvedCommand)
                    case .terminal:
                        result = await executor.executeTerminal(resolvedCommand, terminal, shortcut.terminalBehavior)
                    case .editor:
                        result = await executor.executeEditor(resolvedCommand, editor)
                    }
                    await send(.executionCompleted(result))
                }

            case let .executionCompleted(result):
                switch result {
                case let .success(title):
                    return .run { [toast] _ in await toast.show(title) }
                case let .failure(title, detail):
                    let msg = detail.isEmpty ? title : "\(title): \(detail)"
                    return .run { [toast] _ in await toast.show(msg) }
                }

            // MARK: - Placeholder

            case let .saveLastUsed(id, values):
                state.lastUsedValues[id.uuidString] = values
                return save(state)

            // MARK: - Tools

            case .toggleDisableAll:
                let anyEnabled = state.shortcuts.contains { $0.isEnabled }
                for id in state.shortcuts.ids {
                    state.shortcuts[id: id]?.isEnabled = !anyEnabled
                }
                return .merge(
                    save(state),
                    .run { [anyEnabled, toast] _ in
                        await toast.show(anyEnabled ? "All shortcuts disabled" : "All shortcuts enabled")
                    }
                )

            case .exportJSON:
                let shortcuts = Array(state.shortcuts)
                return .run { [toast, clipboard] _ in
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    if let json = try? encoder.encode(shortcuts),
                       let str = String(data: json, encoding: .utf8) {
                        await clipboard.copyString(str)
                        await toast.show("Shortcuts copied as JSON")
                    }
                }

            case .toggleScreenshotWatcher:
                state.$settings.withLock { $0.screenshotWatcherEnabled.toggle() }
                let enabled = state.settings.screenshotWatcherEnabled
                return .run { [toast, screenshotClient, enabled] _ in
                    await screenshotClient.setEnabled(enabled)
                    await toast.show("Screenshot watcher \(enabled ? "enabled" : "disabled")")
                }

            case let .screenshotDetected(path):
                return .run { [toast, clipboard] _ in
                    await clipboard.copyString(path)
                    let filename = (path as NSString).lastPathComponent
                    await toast.show("Path copied: \(filename)")
                }

            // MARK: - File Import/Export

            case let .importFromFile(url):
                return .run { send in
                    let data = try Data(contentsOf: url)
                    let storeData = try JSONDecoder().decode(StoreData.self, from: data)
                    await send(.importCompleted(storeData))
                }

            case let .importCompleted(storeData):
                for shortcut in storeData.shortcuts {
                    var s = shortcut
                    s.sortOrder = (state.shortcuts.map(\.sortOrder).max() ?? -1) + 1
                    state.shortcuts.append(s)
                }
                for group in storeData.groups {
                    var g = group
                    g.sortOrder = (state.groups.map(\.sortOrder).max() ?? -1) + 1
                    state.groups.append(g)
                }
                return .merge(
                    save(state),
                    .run { [toast, count = storeData.shortcuts.count, gCount = storeData.groups.count] _ in
                        await toast.show("✓ Imported \(count) shortcuts, \(gCount) groups")
                    }
                )

            case let .exportToFile(url):
                let data = StoreData(
                    shortcuts: Array(state.shortcuts),
                    groups: Array(state.groups),
                    lastUsedValues: state.lastUsedValues
                )
                return .run { [toast] _ in
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let json = try encoder.encode(data)
                    try json.write(to: url)
                    await toast.show("✓ Exported to \(url.lastPathComponent)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func save(_ state: State) -> Effect<Action> {
        let data = StoreData(
            shortcuts: Array(state.shortcuts),
            groups: Array(state.groups),
            lastUsedValues: state.lastUsedValues
        )
        return .run { [toast, persistence] _ in
            do {
                try await persistence.save(data)
            } catch {
                SBLog.store.error("Save failed: \(error.localizedDescription)")
                await toast.show("Save failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - State Helpers

extension ShortcutsFeature.State {
    public func enabledShortcuts(inGroup groupId: ShortcutGroup.ID?) -> [Shortcut] {
        shortcuts
            .filter { $0.isEnabled && $0.groupId == groupId }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    public var sortedGroups: [ShortcutGroup] {
        groups.sorted { $0.sortOrder < $1.sortOrder }
    }

    public func getLastUsed(for shortcutId: Shortcut.ID) -> [String: String] {
        lastUsedValues[shortcutId.uuidString] ?? [:]
    }
}
