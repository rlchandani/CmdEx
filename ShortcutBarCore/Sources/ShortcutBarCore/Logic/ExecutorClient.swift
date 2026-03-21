import AppKit
import Dependencies
import DependenciesMacros
import Foundation

/// The outcome of executing a shortcut command.
///
/// - ``success(title:)`` indicates the command ran without error.
/// - ``failure(title:detail:)`` includes a human-readable error message
///   and optional stderr or system error detail.
public enum ExecutionResult: Equatable, Sendable {
    case success(title: String)
    case failure(title: String, detail: String)
}

/// Executes shortcut commands across all supported command types.
///
/// Each method corresponds to a ``CommandType`` and returns an ``ExecutionResult``.
/// The live implementation uses `NSWorkspace`, `Process`, and `NSAppleScript`.
/// The test implementation is a no-op that never performs I/O.
///
/// ## Usage
/// ```swift
/// @Dependency(\.executor) var executor
/// let result = await executor.executeApp("Google Chrome")
/// ```
@DependencyClient
public struct ExecutorClient: Sendable {
    /// Launches a macOS application by name or bundle identifier.
    /// Searches `/Applications`, `/System/Applications`, and `~/Applications`.
    public var executeApp: @Sendable (_ name: String) async -> ExecutionResult = { _ in .success(title: "") }

    /// Opens a URL in the system default browser.
    public var executeURL: @Sendable (_ urlString: String) async -> ExecutionResult = { _ in .success(title: "") }

    /// Opens a URL in a specific browser identified by bundle ID.
    /// Falls back to the default browser if the specified browser is not installed.
    public var executeURLInBrowser: @Sendable (_ urlString: String, _ browserBundleId: String) async -> ExecutionResult = { _, _ in .success(title: "") }

    /// Opens a file or folder in Finder. Supports tilde expansion (`~/`).
    public var executeFileOrFolder: @Sendable (_ path: String) async -> ExecutionResult = { _ in .success(title: "") }

    /// Runs a shell command in the background via `/bin/zsh -c`.
    /// Returns the exit status and stderr on failure.
    public var executeShell: @Sendable (_ command: String) async -> ExecutionResult = { _ in .success(title: "") }

    /// Sends a command to a terminal emulator via AppleScript.
    /// Supports iTerm2 and Terminal.app with configurable tab/window behavior.
    /// Falls back to Terminal.app if the preferred terminal is not installed.
    public var executeTerminal: @Sendable (_ command: String, _ terminalBundleId: String, _ behavior: TerminalBehavior) async -> ExecutionResult = { _, _, _ in .success(title: "") }

    /// Opens a file in a text editor identified by bundle ID.
    /// Falls back to the system default application for the file type.
    public var executeEditor: @Sendable (_ path: String, _ editorBundleId: String) async -> ExecutionResult = { _, _ in .success(title: "") }
}

extension ExecutorClient: DependencyKey {
    public static let liveValue = ExecutorClient(
        executeApp: { name in
            await MainActor.run {
                let logger = SBLog.executor
                let path = name.hasSuffix(".app") ? name : name
                let searchPaths = [
                    "/Applications/\(path).app",
                    "/System/Applications/\(path).app",
                    "\(NSHomeDirectory())/Applications/\(path).app",
                ]
                if let found = searchPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: found))
                    logger.info("Launched app: \(path)")
                    return .success(title: "Launched \(path)")
                } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
                    NSWorkspace.shared.openApplication(at: url, configuration: .init())
                    logger.info("Launched app by bundle ID: \(name)")
                    return .success(title: "Launched \(name)")
                }
                logger.error("App not found: \(path)")
                return .failure(title: "App not found", detail: path)
            }
        },
        executeURL: { urlString in
            await MainActor.run {
                guard let url = URL(string: urlString), NSWorkspace.shared.open(url) else {
                    SBLog.executor.error("Invalid URL: \(urlString)")
                    return .failure(title: "Invalid URL", detail: urlString)
                }
                SBLog.executor.info("Opened URL: \(urlString)")
                return .success(title: "Opened URL")
            }
        },
        executeURLInBrowser: { urlString, browserBundleId in
            await MainActor.run {
                guard let url = URL(string: urlString) else {
                    SBLog.executor.error("Invalid URL: \(urlString)")
                    return .failure(title: "Invalid URL", detail: urlString)
                }
                if let browserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserBundleId) {
                    let config = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: config)
                    SBLog.executor.info("Opened URL in \(browserBundleId): \(urlString)")
                    return .success(title: "Opened URL")
                }
                NSWorkspace.shared.open(url)
                SBLog.executor.info("Opened URL (default browser): \(urlString)")
                return .success(title: "Opened URL")
            }
        },
        executeFileOrFolder: { path in
            await MainActor.run {
                let expanded = NSString(string: path).expandingTildeInPath
                guard FileManager.default.fileExists(atPath: expanded) else {
                    SBLog.executor.error("Path not found: \(path)")
                    return .failure(title: "Path not found", detail: path)
                }
                NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
                SBLog.executor.info("Opened path: \(expanded)")
                return .success(title: "Opened \(URL(fileURLWithPath: expanded).lastPathComponent)")
            }
        },
        executeShell: { command in
            let logger = SBLog.executor
            logger.info("Running shell: \(command)")
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    return .success(title: "✓ Command completed")
                }
                let stderr = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                logger.error("Shell failed (\(process.terminationStatus)): \(stderr)")
                return .failure(title: "✗ Command failed", detail: stderr)
            } catch {
                logger.error("Shell error: \(error.localizedDescription)")
                return .failure(title: "Failed", detail: error.localizedDescription)
            }
        },
        executeTerminal: { command, terminalBundleId, behavior in
            await MainActor.run {
                let logger = SBLog.terminal
                let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")

                let isInstalled = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleId) != nil
                let activeBundleId = isInstalled ? terminalBundleId : "com.apple.Terminal"

                let appName: String
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: activeBundleId) {
                    appName = url.deletingPathExtension().lastPathComponent
                } else {
                    appName = "Terminal"
                }

                if !isInstalled {
                    logger.warning("\(terminalBundleId) not found, falling back to Terminal.app")
                }

                let script: String
                if activeBundleId == "com.googlecode.iterm2" {
                    script = behavior == .newTab
                        ? """
                        tell application "iTerm"
                            activate
                            tell current window
                                create tab with default profile
                                tell current session
                                    write text "\(escaped)"
                                end tell
                            end tell
                        end tell
                        """
                        : """
                        tell application "iTerm"
                            activate
                            set newWindow to (create window with default profile)
                            tell current session of newWindow
                                write text "\(escaped)"
                            end tell
                        end tell
                        """
                } else if activeBundleId == "com.apple.Terminal" {
                    script = behavior == .newTab
                        ? """
                        tell application "Terminal"
                            activate
                            if (count of windows) > 0 then
                                do script "\(escaped)" in window 1
                            else
                                do script "\(escaped)"
                            end if
                        end tell
                        """
                        : """
                        tell application "Terminal"
                            activate
                            do script "\(escaped)"
                        end tell
                        """
                } else {
                    script = """
                    tell application "\(appName)" to activate
                    """
                }

                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&error)
                    if let error {
                        let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                        logger.error("AppleScript error: \(msg)")
                        return .failure(title: "Terminal error", detail: msg)
                    }
                    logger.info("Terminal command sent via \(appName): \(command)")
                    return .success(title: "✓ Sent to \(appName)")
                }
                return .failure(title: "Failed to create AppleScript", detail: "")
            }
        },
        executeEditor: { path, editorBundleId in
            await MainActor.run {
                let logger = SBLog.executor
                let expanded = NSString(string: path).expandingTildeInPath
                let fileURL = URL(fileURLWithPath: expanded)
                guard FileManager.default.fileExists(atPath: expanded) else {
                    logger.error("File not found: \(path)")
                    return .failure(title: "File not found", detail: path)
                }
                if !editorBundleId.isEmpty,
                   let editorURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: editorBundleId) {
                    let config = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.open([fileURL], withApplicationAt: editorURL, configuration: config)
                    let name = editorURL.deletingPathExtension().lastPathComponent
                    logger.info("Opened \(path) in \(name)")
                    return .success(title: "Opened in \(name)")
                }
                NSWorkspace.shared.open(fileURL)
                logger.info("Opened \(path) in default editor")
                return .success(title: "Opened \(fileURL.lastPathComponent)")
            }
        }
    )

    public static let testValue = ExecutorClient()
}

extension DependencyValues {
    /// Executes shortcut commands. See ``ExecutorClient`` for details.
    public var executor: ExecutorClient {
        get { self[ExecutorClient.self] }
        set { self[ExecutorClient.self] = newValue }
    }
}
