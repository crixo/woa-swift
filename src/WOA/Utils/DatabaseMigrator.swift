import Foundation

/// Handles database normalization for imported SQLite files so they operate reliably
/// in the sandboxed application storage location.
enum DatabaseMigrator {

    /// Ensures the copied database is not expecting a WAL sidecar that is not present in app storage.
    static func migrateIfNeeded(fileURL: URL) throws {
        removeStaleJournalFiles(for: fileURL)

        do {
            let connection = try SQLiteConnection(fileURL: fileURL, readOnly: false)
            try connection.execute("PRAGMA foreign_keys=ON;")
            try connection.execute("PRAGMA journal_mode=DELETE;")
            try connection.execute("VACUUM;")
        } catch {
            AppLogger.warning("Database normalization warning for \(fileURL.path): \(error.localizedDescription)")
            // Ignore journal-mode issues from a source database that is already open elsewhere.
            // The important part is that we import the base database file and do not fail the selection flow.
        }
    }

    private static func removeStaleJournalFiles(for fileURL: URL) {
        let walURL = fileURL.appendingPathExtension("db-wal")
        let shmURL = fileURL.appendingPathExtension("db-shm")

        let manager = FileManager.default
        for url in [walURL, shmURL] {
            guard manager.fileExists(atPath: url.path) else { continue }
            do {
                try manager.removeItem(at: url)
            } catch {
                AppLogger.warning("Unable to remove stale SQLite journal at \(url.path): \(error.localizedDescription)")
            }
        }
    }
}
