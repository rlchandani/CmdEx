import ComposableArchitecture
import Foundation
import Testing
@testable import ShortcutBarCore

// MARK: - Model Tests

@Suite("Shortcut Model")
struct ShortcutTests {
    @Test("Placeholders extracted from command")
    func placeholderExtraction() {
        let s = Shortcut(title: "SSH", command: "ssh {user}@{host}", commandType: .terminal)
        #expect(s.placeholders == ["user", "host"])
    }

    @Test("No placeholders returns empty")
    func noPlaceholders() {
        let s = Shortcut(title: "Chrome", command: "Google Chrome", commandType: .app)
        #expect(s.placeholders.isEmpty)
    }

    @Test("Resolved command substitutes all placeholders")
    func resolvedCommand() {
        let s = Shortcut(title: "SSH", command: "ssh {user}@{host} -p {port}", commandType: .terminal)
        #expect(s.resolvedCommand(with: ["user": "admin", "host": "10.0.0.1", "port": "22"]) == "ssh admin@10.0.0.1 -p 22")
    }

    @Test("Duplicate placeholders resolved")
    func duplicatePlaceholders() {
        let s = Shortcut(title: "Echo", command: "echo {name} {name}", commandType: .shell)
        #expect(s.resolvedCommand(with: ["name": "world"]) == "echo world world")
    }

    @Test("Backward compat: missing terminalBehavior defaults to newTab")
    func backwardCompat() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","title":"T","command":"c","commandType":"shell","isEnabled":true,"sortOrder":0}
        """
        let s = try JSONDecoder().decode(Shortcut.self, from: json.data(using: .utf8)!)
        #expect(s.terminalBehavior == .newTab)
    }
}

@Suite("ShortcutGroup Model")
struct ShortcutGroupTests {
    @Test("Default init")
    func defaultInit() {
        let g = ShortcutGroup(name: "Dev")
        #expect(g.name == "Dev")
        #expect(g.sortOrder == 0)
    }
}

@Suite("StoreData Codable")
struct StoreDataTests {
    @Test("Round-trip encode/decode")
    func roundTrip() throws {
        let original = StoreData(
            shortcuts: [Shortcut(title: "T", command: "c", commandType: .shell)],
            groups: [ShortcutGroup(name: "G")],
            lastUsedValues: ["k": ["p": "v"]]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StoreData.self, from: data)
        #expect(decoded == original)
    }

    @Test("Decodes fixture file")
    func decodeFixture() throws {
        let url = Bundle.module.url(forResource: "sample_store", withExtension: "json", subdirectory: "Fixtures")!
        let data = try Data(contentsOf: url)
        let store = try JSONDecoder().decode(StoreData.self, from: data)
        #expect(store.shortcuts.count == 1)
        #expect(store.shortcuts[0].title == "Test Chrome")
    }
}

@Suite("CommandType")
struct CommandTypeTests {
    @Test("All cases have labels")
    func allLabels() {
        for type in CommandType.allCases {
            #expect(!type.label.isEmpty)
        }
    }

    @Test("All cases have icons")
    func allIcons() {
        for type in CommandType.allCases {
            #expect(!SBIcon.forCommandType(type).isEmpty)
        }
    }
}

@Suite("Constants")
struct ConstantsTests {
    @Test("Default time zone IDs are valid")
    func validTimeZones() {
        for id in SBConstants.defaultTimeZoneIds {
            #expect(TimeZone(identifier: id) != nil)
        }
    }

    @Test("All defaults keys are non-empty")
    func nonEmptyKeys() {
        let keys = [
            SBDefaultsKey.launchAtLogin, SBDefaultsKey.preferredTerminal,
            SBDefaultsKey.preferredBrowser, SBDefaultsKey.preferredEditor,
            SBDefaultsKey.showTimeZoneClock, SBDefaultsKey.timeZoneIdentifiers,
            SBDefaultsKey.screenshotWatcherEnabled,
        ]
        for key in keys { #expect(!key.isEmpty) }
    }
}

@Suite("AppSettings")
struct AppSettingsTests {
    @Test("Default settings are sensible")
    func defaults() {
        let s = AppSettings()
        #expect(s.preferredTerminal == SBConstants.defaultTerminalBundleId)
        #expect(s.preferredBrowser.isEmpty)
        #expect(s.preferredEditor.isEmpty)
        #expect(!s.launchAtLogin)
        #expect(s.showTimeZoneClock)
        #expect(s.timeZoneIdentifiers == SBConstants.defaultTimeZoneIds)
        #expect(!s.screenshotWatcherEnabled)
    }

    @Test("Round-trip encode/decode")
    func roundTrip() throws {
        var s = AppSettings()
        s.preferredBrowser = "com.google.Chrome"
        s.launchAtLogin = true
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded == s)
    }
}
