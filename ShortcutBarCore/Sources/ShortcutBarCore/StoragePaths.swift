import Foundation

public extension URL {
    static var shortcutBarApplicationSupport: URL {
        get throws {
            let fm = FileManager.default
            let appSupport = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = appSupport.appendingPathComponent(SBConstants.bundleIdentifier, isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
    }

    static var shortcutBarSettingsURL: URL {
        get throws {
            try shortcutBarApplicationSupport.appendingPathComponent("shortcuts.json")
        }
    }
}
