import Foundation

public enum TerminalBehavior: String, Codable, CaseIterable, Sendable {
    case newWindow = "New Window"
    case newTab = "New Tab"
}

public struct Shortcut: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var command: String
    public var commandType: CommandType
    public var isEnabled: Bool
    public var groupId: UUID?
    public var sortOrder: Int
    public var terminalBehavior: TerminalBehavior

    public init(
        id: UUID = UUID(),
        title: String,
        command: String,
        commandType: CommandType,
        isEnabled: Bool = true,
        groupId: UUID? = nil,
        sortOrder: Int = 0,
        terminalBehavior: TerminalBehavior = .newTab
    ) {
        self.id = id
        self.title = title
        self.command = command
        self.commandType = commandType
        self.isEnabled = isEnabled
        self.groupId = groupId
        self.sortOrder = sortOrder
        self.terminalBehavior = terminalBehavior
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        command = try c.decode(String.self, forKey: .command)
        commandType = try c.decode(CommandType.self, forKey: .commandType)
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
        groupId = try c.decodeIfPresent(UUID.self, forKey: .groupId)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        terminalBehavior = try c.decodeIfPresent(TerminalBehavior.self, forKey: .terminalBehavior) ?? .newTab
    }

    private static let placeholderRegex = try? NSRegularExpression(pattern: "\\{(\\w+)\\}")

    public var placeholders: [String] {
        guard let regex = Self.placeholderRegex else { return [] }
        let matches = regex.matches(in: command, range: NSRange(command.startIndex..., in: command))
        return matches.compactMap { Range($0.range(at: 1), in: command).map { String(command[$0]) } }
    }

    public func resolvedCommand(with values: [String: String]) -> String {
        values.reduce(command) { result, pair in
            result.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }
}
