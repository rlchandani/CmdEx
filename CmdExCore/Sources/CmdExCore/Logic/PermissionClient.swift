import AppKit
import Dependencies
import DependenciesMacros
import Foundation

/// Permission status snapshot.
public struct PermissionStatus: Equatable, Sendable {
    public var accessibility: Bool
    public var automation: Bool
    public var fullDiskAccess: Bool

    public init(accessibility: Bool = false, automation: Bool = false, fullDiskAccess: Bool = false) {
        self.accessibility = accessibility
        self.automation = automation
        self.fullDiskAccess = fullDiskAccess
    }

    public var anyMissing: Bool { !accessibility || !automation || !fullDiskAccess }

    public var missingMessage: String? {
        var missing: [String] = []
        if !accessibility { missing.append("Accessibility") }
        if !automation { missing.append("Automation") }
        if !fullDiskAccess { missing.append("Full Disk Access") }
        guard !missing.isEmpty else { return nil }
        return "\(missing.joined(separator: ", ")) — required for the app to work."
    }
}

/// Checks macOS TCC permission status.
@DependencyClient
public struct PermissionClient: Sendable {
    /// Returns current permission status for all required services.
    public var check: @Sendable @MainActor () -> PermissionStatus = { PermissionStatus() }
}

extension PermissionClient: DependencyKey {
    public static let liveValue = PermissionClient(
        check: {
            PermissionStatus(
                accessibility: AXIsProcessTrusted(),
                automation: checkAutomation(),
                fullDiskAccess: FileManager.default.isReadableFile(
                    atPath: "/Library/Application Support/com.apple.TCC/TCC.db"
                )
            )
        }
    )

    public static let testValue = PermissionClient()

    @MainActor
    private static func checkAutomation() -> Bool {
        let script = NSAppleScript(source: """
            tell application "System Events" to return name of first process whose frontmost is true
        """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        return error == nil
    }
}

extension DependencyValues {
    /// macOS TCC permission checker. See ``PermissionClient``.
    public var permissions: PermissionClient {
        get { self[PermissionClient.self] }
        set { self[PermissionClient.self] = newValue }
    }
}
