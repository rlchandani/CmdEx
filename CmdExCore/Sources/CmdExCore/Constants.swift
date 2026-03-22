import Foundation

/// Central constants for CmdEx.
public enum SBConstants {
    public static let bundleIdentifier = "com.cmdex.app"

    // MARK: - Timing

    public static let iconFlashDuration: TimeInterval = 1.5
    public static let converterShowDelay: TimeInterval = 0.1
    public static let toastDisplayDuration: TimeInterval = 2.5
    public static let fsEventLatency: TimeInterval = 0.1

    // MARK: - Layout

    public static let popoverWidth: CGFloat = 280
    public static let scrollMaxHeight: CGFloat = 420
    public static let rowPaddingH: CGFloat = 12
    public static let rowPaddingV: CGFloat = 8
    public static let iconFrameWidth: CGFloat = 18
    public static let toastTopPadding: CGFloat = 48

    // MARK: - Defaults

    public static let defaultTimeZoneIds = ["UTC", "America/Los_Angeles"]
    public static let defaultTerminalBundleId = "com.googlecode.iterm2"

    // MARK: - Changelog

    public static let changelog = """
    • Initial release
    • Menu bar shortcut manager with groups and submenus
    • App, shell, terminal, URL, file/folder, and editor commands
    • Placeholder parameters with last-used memory
    • iTerm2 support with Terminal.app fallback
    • Configurable new tab / new window for terminal commands
    • Drag-and-drop reordering for shortcuts and groups
    • Configurable default terminal, browser, and text editor
    • Screenshot watcher — copies new screenshot paths to clipboard
    • Time converter with working hours indicators
    • Toast notifications — non-intrusive HUD alerts
    • Launch at login support
    • Sparkle auto-updates
    """
}

/// Safe URL constants (avoids force-unwraps in view code).
public enum SBURLs {
    // swiftlint:disable force_unwrapping
    public static let github = URL(string: "https://github.com/rlchandani/CmdEx")!
    public static let author = URL(string: "https://rlchandani.dev/")!
    public static let browserDiscovery = URL(string: "https://example.com")!
    // swiftlint:enable force_unwrapping
}

/// SF Symbol names for command types.
public enum SBIcon {
    public static func forCommandType(_ type: CommandType) -> String {
        switch type {
        case .app: "app.dashed"
        case .shell: "terminal"
        case .terminal: "terminal.fill"
        case .url: "globe"
        case .fileOrFolder: "folder"
        case .editor: "pencil.line"
        }
    }
}
