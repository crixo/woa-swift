import Foundation

/// Scaffolded for future schema migrations. Currently a no-op since the app
/// does not modify the schema of user-provided databases.
enum DatabaseMigrator {

    /// Runs any pending migrations against the installed application database.
    /// No-op today; reserved for future schema evolution.
    static func migrateIfNeeded(fileURL: URL) throws {
        // Intentionally empty: no migrations are defined yet.
    }
}
