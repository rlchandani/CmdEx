import Foundation

public struct StoreData: Codable, Equatable, Sendable {
    public var shortcuts: [Shortcut]
    public var groups: [ShortcutGroup]
    public var lastUsedValues: [String: [String: String]]

    public init(
        shortcuts: [Shortcut] = [],
        groups: [ShortcutGroup] = [],
        lastUsedValues: [String: [String: String]] = [:]
    ) {
        self.shortcuts = shortcuts
        self.groups = groups
        self.lastUsedValues = lastUsedValues
    }
}
