import ComposableArchitecture
import Foundation
import Testing
@testable import CmdExCore

// Note: Full TestStore reducer tests are now in ReducerTests.swift.
// These tests verify the core logic patterns used by ShortcutsFeature.

@Suite("Shortcut Filtering")
struct ShortcutFilterTests {
    @Test("Filter by title")
    func filterByTitle() {
        let shortcuts = [
            Shortcut(title: "Google Chrome", command: "Google Chrome", commandType: .app),
            Shortcut(title: "SSH Server", command: "ssh root@host", commandType: .terminal),
        ]
        let q = "ssh"
        let filtered = shortcuts.filter { $0.title.lowercased().contains(q) || $0.command.lowercased().contains(q) }
        #expect(filtered.count == 1)
        #expect(filtered[0].title == "SSH Server")
    }

    @Test("Filter by command")
    func filterByCommand() {
        let shortcuts = [
            Shortcut(title: "Config", command: "~/.zshrc", commandType: .editor),
            Shortcut(title: "Browser", command: "https://google.com", commandType: .url),
        ]
        let filtered = shortcuts.filter { $0.command.lowercased().contains("zshrc") }
        #expect(filtered.count == 1)
    }

    @Test("Empty search returns all")
    func emptySearch() {
        let shortcuts = [
            Shortcut(title: "A", command: "a", commandType: .shell),
            Shortcut(title: "B", command: "b", commandType: .shell),
        ]
        let q = ""
        let filtered = q.isEmpty ? shortcuts : shortcuts.filter { $0.title.lowercased().contains(q) }
        #expect(filtered.count == 2)
    }
}

@Suite("Enabled Shortcuts Filtering")
struct EnabledShortcutsTests {
    @Test("Filters by group and enabled status")
    func filterByGroupAndEnabled() {
        let groupId = UUID()
        let shortcuts = [
            Shortcut(title: "A", command: "a", commandType: .shell, isEnabled: true, groupId: nil, sortOrder: 0),
            Shortcut(title: "B", command: "b", commandType: .shell, isEnabled: false, groupId: nil, sortOrder: 1),
            Shortcut(title: "C", command: "c", commandType: .shell, isEnabled: true, groupId: groupId, sortOrder: 0),
        ]
        let ungrouped = shortcuts.filter { $0.isEnabled && $0.groupId == nil }
        #expect(ungrouped.count == 1)
        #expect(ungrouped[0].title == "A")

        let grouped = shortcuts.filter { $0.isEnabled && $0.groupId == groupId }
        #expect(grouped.count == 1)
        #expect(grouped[0].title == "C")
    }

    @Test("Sort order respected")
    func sortOrder() {
        let shortcuts = [
            Shortcut(title: "B", command: "b", commandType: .shell, sortOrder: 2),
            Shortcut(title: "A", command: "a", commandType: .shell, sortOrder: 0),
            Shortcut(title: "C", command: "c", commandType: .shell, sortOrder: 1),
        ]
        let sorted = shortcuts.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted.map(\.title) == ["A", "C", "B"])
    }
}

@Suite("Group Sorting")
struct GroupSortTests {
    @Test("Groups sort by sortOrder")
    func sortOrder() {
        let groups = [
            ShortcutGroup(name: "Z", sortOrder: 2),
            ShortcutGroup(name: "A", sortOrder: 0),
            ShortcutGroup(name: "M", sortOrder: 1),
        ]
        let sorted = groups.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted.map(\.name) == ["A", "M", "Z"])
    }
}

@Suite("Persistence Client")
struct PersistenceClientTests {
    @Test("Live value type exists")
    func liveValueExists() {
        // Verify the live value can be constructed (don't call it — it touches disk)
        let _ = PersistenceClient.liveValue
    }
}

@Suite("Executor Client")
struct ExecutorClientTests {
    @Test("ExecutionResult equality")
    func resultEquality() {
        let a = ExecutionResult.success(title: "OK")
        let b = ExecutionResult.success(title: "OK")
        let c = ExecutionResult.failure(title: "Err", detail: "d")
        #expect(a == b)
        #expect(a != c)
    }
}
