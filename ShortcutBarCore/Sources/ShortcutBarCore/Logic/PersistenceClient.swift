import Dependencies
import DependenciesMacros
import Foundation

/// Manages persistence for shortcuts, groups, and last-used placeholder values.
///
/// Data is stored as JSON in `~/Library/Application Support/com.shortcutbar.app/shortcuts.json`.
/// All methods throw ``PersistenceError`` on failure.
/// The test implementation returns empty data and never performs I/O.
///
/// ## Usage
/// ```swift
/// @Dependency(\.persistence) var persistence
/// let data = try await persistence.load()
/// ```
@DependencyClient
public struct PersistenceClient: Sendable {
    /// Loads all shortcuts, groups, and last-used values from disk.
    /// Returns empty ``StoreData`` if no file exists yet.
    public var load: @Sendable () async throws -> StoreData = { StoreData() }

    /// Atomically writes shortcuts, groups, and last-used values to disk.
    public var save: @Sendable (_ data: StoreData) async throws -> Void
}

extension PersistenceClient: DependencyKey {
    public static let liveValue: PersistenceClient = {
        let logger = SBLog.store
        return PersistenceClient(
            load: {
                let url = try URL.shortcutBarSettingsURL
                guard FileManager.default.fileExists(atPath: url.path) else {
                    logger.info("No existing data file, returning defaults")
                    return StoreData()
                }
                let data = try Data(contentsOf: url)
                let store = try JSONDecoder().decode(StoreData.self, from: data)
                logger.info("Loaded \(store.shortcuts.count) shortcuts, \(store.groups.count) groups")
                return store
            },
            save: { storeData in
                let url = try URL.shortcutBarSettingsURL
                let data = try JSONEncoder().encode(storeData)
                try data.write(to: url, options: .atomic)
                logger.info("Saved \(storeData.shortcuts.count) shortcuts, \(storeData.groups.count) groups")
            }
        )
    }()

    public static let testValue = PersistenceClient()
}

extension DependencyValues {
    /// Persists shortcuts and groups to disk. See ``PersistenceClient``.
    public var persistence: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}
