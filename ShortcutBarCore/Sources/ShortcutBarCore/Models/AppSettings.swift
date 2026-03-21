import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

/// App settings stored via TCA @Shared file storage.
/// Replaces all direct UserDefaults access.
public struct AppSettings: Codable, Equatable, Sendable {
    public var preferredTerminal: String
    public var preferredBrowser: String
    public var preferredEditor: String
    public var launchAtLogin: Bool
    public var showTimeZoneClock: Bool
    public var timeZoneIdentifiers: [String]
    public var screenshotWatcherEnabled: Bool

    public init(
        preferredTerminal: String = SBConstants.defaultTerminalBundleId,
        preferredBrowser: String = "",
        preferredEditor: String = "",
        launchAtLogin: Bool = false,
        showTimeZoneClock: Bool = true,
        timeZoneIdentifiers: [String] = SBConstants.defaultTimeZoneIds,
        screenshotWatcherEnabled: Bool = false
    ) {
        self.preferredTerminal = preferredTerminal
        self.preferredBrowser = preferredBrowser
        self.preferredEditor = preferredEditor
        self.launchAtLogin = launchAtLogin
        self.showTimeZoneClock = showTimeZoneClock
        self.timeZoneIdentifiers = timeZoneIdentifiers
        self.screenshotWatcherEnabled = screenshotWatcherEnabled
    }
}

/// File storage key for TCA @Shared.

extension SharedReaderKey where Self == FileStorageKey<AppSettings>.Default {
    public static var appSettings: Self {
        Self[
            .fileStorage(
                URL.applicationSupportDirectory
                    .appending(component: SBConstants.bundleIdentifier)
                    .appending(component: "settings.json")
            ),
            default: AppSettings()
        ]
    }
}
