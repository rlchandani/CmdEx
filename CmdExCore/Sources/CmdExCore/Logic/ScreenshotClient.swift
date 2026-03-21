import Dependencies
import DependenciesMacros
import Foundation

/// Monitors the filesystem for new screenshots and copies their paths to the clipboard.
///
/// The live implementation is wired in ``AppDelegate`` to the ``ScreenshotWatcher`` singleton.
/// The test implementation is a no-op.
///
/// ## Usage
/// ```swift
/// @Dependency(\.screenshotClient) var screenshotClient
/// await screenshotClient.setEnabled(true)
/// ```
@DependencyClient
public struct ScreenshotClient: Sendable {
    /// Starts monitoring the screenshot directory for new files.
    public var start: @Sendable @MainActor () -> Void

    /// Stops monitoring.
    public var stop: @Sendable @MainActor () -> Void

    /// Enables or disables the watcher. Persists the preference.
    public var setEnabled: @Sendable @MainActor (_ enabled: Bool) -> Void

    /// Returns whether the watcher is currently enabled.
    public var isEnabled: @Sendable @MainActor () -> Bool = { false }
}

extension ScreenshotClient: DependencyKey {
    /// Live value must be registered by the app target via ``registerLive()``.
    // SAFETY: Written once in AppDelegate static initializer before store creation, read-only thereafter.
    public nonisolated(unsafe) static var liveValue = ScreenshotClient()
    public static let testValue = ScreenshotClient()
}

extension DependencyValues {
    /// Screenshot path watcher. See ``ScreenshotClient``.
    public var screenshotClient: ScreenshotClient {
        get { self[ScreenshotClient.self] }
        set { self[ScreenshotClient.self] = newValue }
    }
}
