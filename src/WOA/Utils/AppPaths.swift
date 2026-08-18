import Foundation

/// Provides sandbox-safe URLs for all application-owned storage locations.
enum AppPaths {

    /// Root application directory: `Application Support/WOA`.
    static func appSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("WOA", isDirectory: true)
        try createDirectoryIfNeeded(at: root)
        return root
    }

    static func databaseDirectory() throws -> URL {
        try subdirectory("database")
    }

    static func configurationDirectory() throws -> URL {
        try subdirectory("configuration")
    }

    static func logsDirectory() throws -> URL {
        try subdirectory("logs")
    }

    static func cacheDirectory() throws -> URL {
        try subdirectory("cache")
    }

    /// Destination URL for the imported application database.
    static func databaseFileURL() throws -> URL {
        try databaseDirectory().appendingPathComponent("woa.db", isDirectory: false)
    }

    /// Destination URL for the persisted app configuration file.
    static func configurationFileURL() throws -> URL {
        try configurationDirectory().appendingPathComponent("app-settings.json", isDirectory: false)
    }

    /// Destination URL for the current log file.
    static func logFileURL() throws -> URL {
        try logsDirectory().appendingPathComponent("app.log", isDirectory: false)
    }

    private static func subdirectory(_ name: String) throws -> URL {
        let url = try appSupportDirectory().appendingPathComponent(name, isDirectory: true)
        try createDirectoryIfNeeded(at: url)
        return url
    }

    private static func createDirectoryIfNeeded(at url: URL) throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
