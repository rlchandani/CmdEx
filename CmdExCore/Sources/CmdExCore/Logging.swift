import os.log

/// Shared logging infrastructure for CmdEx, mirroring Hex's HexLog pattern.
public enum SBLog {
    public static let subsystem = "com.cmdex.app"

    public enum Category: String {
        case app = "App"
        case executor = "Executor"
        case store = "Store"
        case menu = "Menu"
        case settings = "Settings"
        case terminal = "Terminal"
    }

    public static func logger(_ category: Category) -> os.Logger {
        os.Logger(subsystem: subsystem, category: category.rawValue)
    }

    public static let app = logger(.app)
    public static let executor = logger(.executor)
    public static let store = logger(.store)
    public static let menu = logger(.menu)
    public static let settings = logger(.settings)
    public static let terminal = logger(.terminal)
}
