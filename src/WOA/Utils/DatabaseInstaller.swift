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

        // Checkpoint the source database to ensure all WAL data is written to the main file
        try checkpointDatabase(at: sourceURL)

        let destinationURL = try AppPaths.databaseFileURL()

        if sourceURL.standardizedFileURL != destinationURL.standardizedFileURL {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }

        try DatabaseMigrator.migrateIfNeeded(fileURL: destinationURL)
        try DatabaseValidator.validate(fileURL: destinationURL)

        AppLogger.info("✅ Import Database succeeded. Copied database to: \(destinationURL.path)")
        return destinationURL
    }

    /// Checkpoints the database to ensure all committed WAL data is written to the main file.
    /// This guarantees that the main database file contains all committed changes before it is copied.
    private static func checkpointDatabase(at fileURL: URL) throws {
        let connection = try SQLiteConnection(fileURL: fileURL, readOnly: false)
        defer { try? connection.close() }

        // Run a RESTART checkpoint to move all data from WAL to the main database file
        try connection.execute("PRAGMA wal_checkpoint(RESTART);")
    }
}
