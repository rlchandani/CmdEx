import AppKit
import ComposableArchitecture
import Foundation
import CmdExCore

/// Owns shortcuts CRUD, groups, reordering, and execution.
@Reducer
struct ShortcutsFeature {
    @ObservableState
    struct State: Equatable {
        var shortcuts: IdentifiedArrayOf<Shortcut> = []
        var groups: IdentifiedArrayOf<ShortcutGroup> = []
        var lastUsedValues: [String: [String: String]] = [:]
        var recentIds: [Shortcut.ID] = []
        var isLoading = false
        @Shared(.appSettings) var settings: AppSettings

        var recentShortcuts: [Shortcut] {
            recentIds.compactMap { shortcuts[id: $0] }.prefix(3).map { $0 }
        }
    }

    enum Action {
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
    }

    @Dependency(\.persistence) var persistence
    @Dependency(\.executor) var executor
    @Dependency(\.toast) var toast
    @Dependency(\.screenshotClient) var screenshotClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadData:
                state.isLoading = true
                return .run { send in
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
                return .run { send in
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
                return .run { [toast] _ in
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    if let json = try? encoder.encode(shortcuts),
                       let str = String(data: json, encoding: .utf8) {
                        await MainActor.run {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(str, forType: .string)
                        }
                        await toast.show("Shortcuts copied as JSON")
                    }
                }

            case .toggleScreenshotWatcher:
                state.$settings.withLock { $0.screenshotWatcherEnabled.toggle() }
                let enabled = state.settings.screenshotWatcherEnabled
                return .run { [toast, enabled] _ in
                    await screenshotClient.setEnabled(enabled)
                    await toast.show("Screenshot watcher \(enabled ? "enabled" : "disabled")")
                }

            case let .screenshotDetected(path):
                return .run { [toast] _ in
                    await MainActor.run {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path, forType: .string)
                    }
                    let filename = (path as NSString).lastPathComponent
                    await toast.show("Path copied: \(filename)")
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
        return .run { [toast] _ in
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
    func enabledShortcuts(inGroup groupId: ShortcutGroup.ID?) -> [Shortcut] {
        shortcuts
            .filter { $0.isEnabled && $0.groupId == groupId }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedGroups: [ShortcutGroup] {
        groups.sorted { $0.sortOrder < $1.sortOrder }
    }

    func getLastUsed(for shortcutId: Shortcut.ID) -> [String: String] {
        lastUsedValues[shortcutId.uuidString] ?? [:]
    }
}
