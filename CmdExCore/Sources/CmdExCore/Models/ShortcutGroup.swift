import Foundation

public struct ShortcutGroup: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var sortOrder: Int

    /// Default parameter `UUID()` is intentional for convenience construction.
    /// Reducer-created instances should pass `@Dependency(\.uuid)` explicitly for testability.
    public init(id: UUID = UUID(), name: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}
