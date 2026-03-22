import ComposableArchitecture
import Foundation
import Testing
@testable import CmdExCore

@Suite("AppFeature Reducer")
struct AppFeatureReducerTests {
    @Test("task action dispatches loadData and checks permissions")
    func taskLoadsData() async {
        let store = await TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistence.load = { StoreData() }
            $0.permissions.check = { PermissionStatus(accessibility: true, automation: false, fullDiskAccess: true) }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.task)
        await store.receive(\.permissionsUpdated) {
            $0.permissionStatus = PermissionStatus(accessibility: true, automation: false, fullDiskAccess: true)
        }
        await store.skipInFlightEffects()
    }
}

@Suite("ShortcutsFeature Reducer")
struct ShortcutsFeatureReducerTests {
    @Test("loadData sets shortcuts from persistence")
    func loadData() async {
        let shortcut = Shortcut(title: "Test", command: "echo hi", commandType: .shell)
        let group = ShortcutGroup(name: "G1")
        let storeData = StoreData(shortcuts: [shortcut], groups: [group], lastUsedValues: ["k": ["p": "v"]])

        let store = await TestStore(initialState: ShortcutsFeature.State()) {
            ShortcutsFeature()
        } withDependencies: {
            $0.persistence.load = { storeData }
        }

        await store.send(.loadData) {
            $0.isLoading = true
        }
        await store.receive(\.dataLoaded) {
            $0.isLoading = false
            $0.shortcuts = IdentifiedArray(uniqueElements: [shortcut])
            $0.groups = IdentifiedArray(uniqueElements: [group])
            $0.lastUsedValues = ["k": ["p": "v"]]
        }
    }

    @Test("addShortcut appends and saves")
    func addShortcut() async {
        let saved = LockIsolated(false)
        let store = await TestStore(initialState: ShortcutsFeature.State()) {
            ShortcutsFeature()
        } withDependencies: {
            $0.persistence.save = { _ in saved.setValue(true) }
        }

        let shortcut = Shortcut(title: "New", command: "ls", commandType: .shell)
        await store.send(.addShortcut(shortcut)) {
            var s = shortcut
            s.sortOrder = 0
            $0.shortcuts.append(s)
        }
        #expect(saved.value)
    }

    @Test("deleteShortcut removes and saves")
    func deleteShortcut() async {
        let shortcut = Shortcut(title: "Del", command: "rm", commandType: .shell)
        var state = ShortcutsFeature.State()
        state.shortcuts.append(shortcut)

        let saved = LockIsolated(false)
        let store = await TestStore(initialState: state) {
            ShortcutsFeature()
        } withDependencies: {
            $0.persistence.save = { _ in saved.setValue(true) }
        }

        await store.send(.deleteShortcut(shortcut.id)) {
            $0.shortcuts.remove(id: shortcut.id)
        }
        #expect(saved.value)
    }

    @Test("deleteGroup ungroups shortcuts")
    func deleteGroupUngroups() async {
        let group = ShortcutGroup(name: "G")
        var shortcut = Shortcut(title: "S", command: "c", commandType: .shell, groupId: group.id)
        shortcut.sortOrder = 0
        var state = ShortcutsFeature.State()
        state.shortcuts.append(shortcut)
        state.groups.append(group)

        let store = await TestStore(initialState: state) {
            ShortcutsFeature()
        } withDependencies: {
            $0.persistence.save = { _ in }
        }

        await store.send(.deleteGroup(group.id)) {
            $0.shortcuts[id: shortcut.id]?.groupId = nil
            $0.groups.remove(id: group.id)
        }
    }

    @Test("toggleDisableAll disables all when some enabled")
    func toggleDisableAll() async {
        var s1 = Shortcut(title: "A", command: "a", commandType: .shell, isEnabled: true)
        s1.sortOrder = 0
        var s2 = Shortcut(title: "B", command: "b", commandType: .shell, isEnabled: true)
        s2.sortOrder = 1
        var state = ShortcutsFeature.State()
        state.shortcuts = IdentifiedArray(uniqueElements: [s1, s2])

        let toastMessages = LockIsolated<[String]>([])
        let store = await TestStore(initialState: state) {
            ShortcutsFeature()
        } withDependencies: {
            $0.persistence.save = { _ in }
            $0.toast.show = { msg in toastMessages.withValue { $0.append(msg) } }
        }

        await store.send(.toggleDisableAll) {
            $0.shortcuts[id: s1.id]?.isEnabled = false
            $0.shortcuts[id: s2.id]?.isEnabled = false
        }
        #expect(toastMessages.value.contains("All shortcuts disabled"))
    }

    @Test("executeShortcut tracks recent IDs")
    func executeTracksRecent() async {
        let shortcut = Shortcut(title: "T", command: "echo", commandType: .shell)
        var state = ShortcutsFeature.State()
        state.shortcuts.append(shortcut)

        let store = await TestStore(initialState: state) {
            ShortcutsFeature()
        } withDependencies: {
            $0.executor.executeShell = { _ in .success(title: "OK") }
            $0.toast.show = { _ in }
        }

        await store.send(.executeShortcut(shortcut, resolvedCommand: "echo")) {
            $0.recentIds = [shortcut.id]
        }
        await store.receive(\.executionCompleted)
    }

    @Test("exportJSON copies to clipboard")
    func exportJSON() async {
        let shortcut = Shortcut(title: "T", command: "c", commandType: .shell)
        var state = ShortcutsFeature.State()
        state.shortcuts.append(shortcut)

        let copiedString = LockIsolated<String?>(nil)
        let store = await TestStore(initialState: state) {
            ShortcutsFeature()
        } withDependencies: {
            $0.clipboard.copyString = { str in copiedString.setValue(str) }
            $0.toast.show = { _ in }
        }

        await store.send(.exportJSON)
        #expect(copiedString.value != nil)
        #expect(copiedString.value?.contains("\"T\"") == true)
    }

    @Test("screenshotDetected copies path to clipboard")
    func screenshotDetected() async {
        let copiedString = LockIsolated<String?>(nil)
        let toastMessage = LockIsolated<String?>(nil)
        let store = await TestStore(initialState: ShortcutsFeature.State()) {
            ShortcutsFeature()
        } withDependencies: {
            $0.clipboard.copyString = { str in copiedString.setValue(str) }
            $0.toast.show = { msg in toastMessage.setValue(msg) }
        }

        await store.send(.screenshotDetected(path: "/tmp/Screenshot-123.png"))
        #expect(copiedString.value == "/tmp/Screenshot-123.png")
        #expect(toastMessage.value?.contains("Screenshot-123.png") == true)
    }
}
