import Foundation

/// Escaping utilities to prevent injection when interpolating user input
/// into shell commands or AppleScript strings.
public enum SBEscape {
    /// Wraps a value in single quotes for safe use in shell commands.
    /// Single quotes inside the value are escaped via the `'\''` idiom.
    /// Example: `hello'world` → `'hello'\''world'`
    public static func shellArgument(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escapes a string for safe interpolation inside AppleScript double-quoted strings.
    /// Handles backslashes, double quotes, and other control characters.
    public static func appleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
