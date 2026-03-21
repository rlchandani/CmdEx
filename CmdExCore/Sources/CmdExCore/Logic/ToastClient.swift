import Dependencies
import DependenciesMacros
import Foundation

/// Displays transient floating toast notifications at the top of the screen.
///
/// Toasts are non-interactive, click-through HUD indicators that auto-dismiss
/// after ``SBConstants/toastDisplayDuration`` seconds. Built on an ``InvisibleWindow``
/// (full-screen transparent `NSPanel`) following the Hex app pattern.
///
/// The live implementation is wired in ``AppDelegate`` to ``ToastWindow``.
/// The test implementation is a no-op.
///
/// ## Usage
/// ```swift
/// @Dependency(\.toast) var toast
/// await toast.show("Screenshot path copied")
/// ```
@DependencyClient
public struct ToastClient: Sendable {
    /// Shows a floating toast message at the top of the screen.
    /// Automatically dismisses after a short delay.
    public var show: @Sendable @MainActor (_ message: String) -> Void
}

extension ToastClient: DependencyKey {
    public nonisolated(unsafe) static var liveValue = ToastClient()
    public static let testValue = ToastClient()
}

extension DependencyValues {
    /// Floating toast notifications. See ``ToastClient``.
    public var toast: ToastClient {
        get { self[ToastClient.self] }
        set { self[ToastClient.self] = newValue }
    }
}
