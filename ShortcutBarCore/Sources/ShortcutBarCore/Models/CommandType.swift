import Foundation

public enum CommandType: String, Codable, CaseIterable, Identifiable, Sendable {
    case app, shell, terminal, url, fileOrFolder, editor

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .app: "Application"
        case .shell: "Shell Command"
        case .terminal: "Terminal Command"
        case .url: "URL"
        case .fileOrFolder: "File / Folder"
        case .editor: "Open in Editor"
        }
    }
}
