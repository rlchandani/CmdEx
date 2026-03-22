import Dependencies
import DependenciesMacros
import Foundation

/// Abstracts clipboard access so the reducer can be tested without AppKit.
@DependencyClient
public struct ClipboardClient: Sendable {
    /// Copies a string to the system clipboard.
    public var copyString: @Sendable @MainActor (_ string: String) -> Void
}

extension ClipboardClient: DependencyKey {
    // SAFETY: Written once in AppDelegate static initializer before store creation, read-only thereafter.
    public nonisolated(unsafe) static var liveValue = ClipboardClient()
    public static let testValue = ClipboardClient()
}

extension DependencyValues {
    /// System clipboard access. See ``ClipboardClient``.
    public var clipboard: ClipboardClient {
        get { self[ClipboardClient.self] }
        set { self[ClipboardClient.self] = newValue }
    }
}
