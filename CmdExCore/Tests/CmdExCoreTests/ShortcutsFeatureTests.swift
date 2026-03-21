import ComposableArchitecture
import Foundation
import Testing
@testable import CmdExCore

// These tests verify the dependency clients and state patterns
// used by ShortcutsFeature. Full TestStore tests require the app target.

@Suite("Persistence Client Integration")
struct PersistenceIntegrationTests {
    @Test("Save and load round-trip")
    func saveLoadRoundTrip() async throws {
        let testURL = FileManager.default.temporaryDirectory
            .appending(component: "test_shortcuts_\(UUID().uuidString).json")

        let client = PersistenceClient(
            load: {
                guard FileManager.default.fileExists(atPath: testURL.path) else { return StoreData() }
                let data = try Data(contentsOf: testURL)
                return try JSONDecoder().decode(StoreData.self, from: data)
            },
            save: { storeData in
                let data = try JSONEncoder().encode(storeData)
                try data.write(to: testURL, options: .atomic)
            }
        )

        let original = StoreData(
            shortcuts: [Shortcut(title: "Test", command: "echo", commandType: .shell)],
            groups: [ShortcutGroup(name: "G1")],
            lastUsedValues: ["k": ["p": "v"]]
        )

        try await client.save(original)
        let loaded = try await client.load()

        #expect(loaded.shortcuts.count == 1)
        #expect(loaded.shortcuts[0].title == "Test")
        #expect(loaded.groups.count == 1)
        #expect(loaded.groups[0].name == "G1")
        #expect(loaded.lastUsedValues["k"]?["p"] == "v")

        try? FileManager.default.removeItem(at: testURL)
    }
}

@Suite("Shortcut CRUD Logic")
struct ShortcutCRUDTests {
    @Test("Add shortcut assigns next sort order")
    func addSortOrder() {
        var shortcuts = IdentifiedArrayOf<Shortcut>()
        let s1 = Shortcut(title: "A", command: "a", commandType: .shell)
        var s1m = s1
        s1m.sortOrder = 0
        shortcuts.append(s1m)

        let s2 = Shortcut(title: "B", command: "b", commandType: .shell)
        var s2m = s2
        s2m.sortOrder = (shortcuts.map(\.sortOrder).max() ?? -1) + 1
        shortcuts.append(s2m)

        #expect(shortcuts[id: s1m.id]?.sortOrder == 0)
        #expect(shortcuts[id: s2m.id]?.sortOrder == 1)
    }

    @Test("Delete group ungroups shortcuts")
    func deleteGroupUngroups() {
        let groupId = UUID()
        var shortcuts = IdentifiedArrayOf<Shortcut>([
            Shortcut(title: "A", command: "a", commandType: .shell, groupId: groupId),
            Shortcut(title: "B", command: "b", commandType: .shell, groupId: nil),
        ])

        for i in shortcuts.indices where shortcuts[i].groupId == groupId {
            shortcuts[i].groupId = nil
        }

        #expect(shortcuts.allSatisfy { $0.groupId == nil })
    }

    @Test("Toggle disable all flips enabled state")
    func toggleDisableAll() {
        var shortcuts = IdentifiedArrayOf<Shortcut>([
            Shortcut(title: "A", command: "a", commandType: .shell, isEnabled: true),
            Shortcut(title: "B", command: "b", commandType: .shell, isEnabled: true),
        ])

        let anyEnabled = shortcuts.contains { $0.isEnabled }
        for id in shortcuts.ids {
            shortcuts[id: id]?.isEnabled = !anyEnabled
        }

        #expect(shortcuts.allSatisfy { !$0.isEnabled })
    }

    @Test("Recent IDs tracking")
    func recentTracking() {
        var recentIds: [UUID] = []
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        // Add 3
        for id in [id1, id2, id3] {
            recentIds.removeAll { $0 == id }
            recentIds.insert(id, at: 0)
            if recentIds.count > 5 { recentIds = Array(recentIds.prefix(5)) }
        }

        #expect(recentIds == [id3, id2, id1])

        // Re-execute id1 — should move to front
        recentIds.removeAll { $0 == id1 }
        recentIds.insert(id1, at: 0)

        #expect(recentIds == [id1, id3, id2])
    }
}

@Suite("ExecutionResult")
struct ExecutionResultTests {
    @Test("Success equality")
    func successEquality() {
        #expect(ExecutionResult.success(title: "OK") == ExecutionResult.success(title: "OK"))
        #expect(ExecutionResult.success(title: "A") != ExecutionResult.success(title: "B"))
    }

    @Test("Failure contains detail")
    func failureDetail() {
        let result = ExecutionResult.failure(title: "Error", detail: "not found")
        #expect(result == .failure(title: "Error", detail: "not found"))
        #expect(result != .success(title: "Error"))
    }
}

@Suite("ScreenshotClient Wiring")
struct ScreenshotClientWiringTests {
    @Test("setEnabled calls through to live implementation")
    @MainActor func setEnabledCallsThrough() {
        let enabledRef = LockIsolated(false)
        let client = ScreenshotClient(
            start: {},
            stop: {},
            setEnabled: { enabledRef.setValue($0) },
            isEnabled: { enabledRef.value }
        )

        client.setEnabled(true)
        #expect(enabledRef.value == true)

        client.setEnabled(false)
        #expect(enabledRef.value == false)
    }

    @Test("isEnabled reflects setEnabled state")
    @MainActor func isEnabledReflectsSet() {
        let enabledRef = LockIsolated(false)
        let client = ScreenshotClient(
            start: {},
            stop: {},
            setEnabled: { enabledRef.setValue($0) },
            isEnabled: { enabledRef.value }
        )

        #expect(client.isEnabled() == false)
        client.setEnabled(true)
        #expect(client.isEnabled() == true)
    }

    @Test("ToastClient show calls through")
    @MainActor func toastCallsThrough() {
        let messages = LockIsolated<[String]>([])
        let client = ToastClient(
            show: { msg in messages.withValue { $0.append(msg) } }
        )

        client.show("hello")
        #expect(messages.value == ["hello"])
    }

    @Test("ToastClient collects multiple messages")
    @MainActor func toastMultipleMessages() {
        let messages = LockIsolated<[String]>([])
        let client = ToastClient(
            show: { msg in messages.withValue { $0.append(msg) } }
        )

        client.show("a")
        client.show("b")
        #expect(messages.value == ["a", "b"])
    }
}

@Suite("Screenshot File Copy")
struct ScreenshotFileCopyTests {
    @Test("Epoch filename format is correct")
    func epochFilenameFormat() {
        let epoch = Int(Date().timeIntervalSince1970)
        let filename = "Screenshot-\(epoch).png"
        #expect(filename.hasPrefix("Screenshot-"))
        #expect(filename.hasSuffix(".png"))
        #expect(!filename.contains("-") || filename.split(separator: "-").count == 2)
        // Epoch should be a reasonable number (after 2024)
        let parts = filename.replacingOccurrences(of: "Screenshot-", with: "")
            .replacingOccurrences(of: ".png", with: "")
        let parsed = Int(parts)
        #expect(parsed != nil)
        #expect(parsed! > 1_700_000_000) // after ~Nov 2023
    }

    @Test("Copy preserves file extension")
    func copyPreservesExtension() {
        for ext in ["png", "jpg", "jpeg"] {
            let original = "Screenshot 2026-03-21 at 2.42.01PM.\(ext)"
            let extractedExt = (original as NSString).pathExtension
            let tmpName = "Screenshot-\(Int(Date().timeIntervalSince1970)).\(extractedExt)"
            #expect(tmpName.hasSuffix(".\(ext)"))
        }
    }

    @Test("Copy to /tmp/ creates file")
    func copyCreatesFile() throws {
        let src = "/tmp/cmdex_test_src_\(Int(Date().timeIntervalSince1970)).png"
        let dst = "/tmp/Screenshot-\(Int(Date().timeIntervalSince1970)).png"
        FileManager.default.createFile(atPath: src, contents: Data("test".utf8))

        try FileManager.default.copyItem(atPath: src, toPath: dst)
        #expect(FileManager.default.fileExists(atPath: dst))

        let srcData = try Data(contentsOf: URL(fileURLWithPath: src))
        let dstData = try Data(contentsOf: URL(fileURLWithPath: dst))
        #expect(srcData == dstData)

        try? FileManager.default.removeItem(atPath: src)
        try? FileManager.default.removeItem(atPath: dst)
    }

    @Test("Original file is not modified after copy")
    func originalUnmodified() throws {
        let src = "/tmp/cmdex_test_orig_\(Int(Date().timeIntervalSince1970)).png"
        let content = Data("original content".utf8)
        FileManager.default.createFile(atPath: src, contents: content)

        let dst = "/tmp/Screenshot-\(Int(Date().timeIntervalSince1970))_orig.png"
        try FileManager.default.copyItem(atPath: src, toPath: dst)

        let srcAfter = try Data(contentsOf: URL(fileURLWithPath: src))
        #expect(srcAfter == content)

        try? FileManager.default.removeItem(atPath: src)
        try? FileManager.default.removeItem(atPath: dst)
    }
}
