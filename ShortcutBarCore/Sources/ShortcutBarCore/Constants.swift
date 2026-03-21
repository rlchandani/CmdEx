import Foundation

/// Central constants for ShortcutBar.
public enum SBConstants {
    public static let bundleIdentifier = "com.cmdex.app"

    // MARK: - Timing

    public static let iconFlashDuration: TimeInterval = 1.5
    public static let converterShowDelay: TimeInterval = 0.1
    public static let toastDisplayDuration: TimeInterval = 2.5
    public static let toastFadeInDuration: TimeInterval = 0.2
    public static let toastFadeOutDuration: TimeInterval = 0.3
    public static let fsEventLatency: TimeInterval = 0.1

    // MARK: - Layout

    public static let popoverWidth: CGFloat = 280
    public static let popoverHeight: CGFloat = 500
    public static let scrollMaxHeight: CGFloat = 420
    public static let rowPaddingH: CGFloat = 12
    public static let rowPaddingV: CGFloat = 8
    public static let iconFrameWidth: CGFloat = 18
    public static let bodyFontSize: CGFloat = 13
    public static let captionFontSize: CGFloat = 12
    public static let timeFontSize: CGFloat = 11
    public static let groupHeaderFontSize: CGFloat = 10
    public static let toastTopPadding: CGFloat = 48

    // MARK: - Defaults

    public static let defaultTimeZoneIds = ["UTC", "America/Los_Angeles"]
    public static let defaultTerminalBundleId = "com.googlecode.iterm2"
}

/// UserDefaults keys — single source of truth.
public enum SBDefaultsKey {
    public static let launchAtLogin = "launchAtLogin"
    public static let preferredTerminal = "preferredTerminal"
    public static let preferredBrowser = "preferredBrowser"
    public static let preferredEditor = "preferredEditor"
    public static let showTimeZoneClock = "showTimeZoneClock"
    public static let timeZoneIdentifiers = "timeZoneIdentifiers"
    public static let screenshotWatcherEnabled = "screenshotWatcherEnabled"
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
