import Foundation

/// Orchestrates the full workflow of importing a user-selected database into Application Support.
enum DatabaseInstaller {

    /// Validates, copies and migrates the database at `sourceURL` into the app's storage location.
    /// - Returns: The URL of the installed database.
    static func install(from sourceURL: URL) throws -> URL {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationURL = try AppPaths.databaseFileURL()

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        try DatabaseMigrator.migrateIfNeeded(fileURL: destinationURL)
        try DatabaseValidator.validate(fileURL: destinationURL)

        AppLogger.info("✅ Import Database succeeded. Copied database to: \(destinationURL.path)")
        return destinationURL
    }
}
