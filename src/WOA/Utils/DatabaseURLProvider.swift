import Foundation

/// Resolves the location of the application-owned SQLite database file.
enum DatabaseURLProvider {

    /// URL of the installed application database inside Application Support.
    static func applicationDatabaseURL() throws -> URL {
        try AppPaths.databaseFileURL()
    }

    /// Whether the application database has already been installed.
    static func isDatabaseInstalled() -> Bool {
        guard let url = try? applicationDatabaseURL() else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}
