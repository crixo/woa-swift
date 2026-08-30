import Foundation
import SQLite3

/// Errors surfaced during database validation.
enum DatabaseValidationError: LocalizedError {
    case missingTables([String])
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .missingTables(let tables):
            return "Database schema not recognized (missing tables: \(tables.joined(separator: ", ")))."
        case .unreadable(let message):
            return "Unable to read database: \(message)"
        }
    }
}

/// Validates that a candidate SQLite file contains the core tables expected by the application.
enum DatabaseValidator {

    /// Tables that must be present for a database to be considered a valid WOA database.
    static let coreTables = [
        "paziente",
        "consulto",
        "esame",
        "trattamento",
        "valutazione",
        "anamnesi_remota",
        "anamnesi_prossima"
    ]

    /// Validates the SQLite file at `url`, throwing if it does not look like a WOA database.
    static func validate(fileURL: URL) throws {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        removeStaleJournalFiles(for: fileURL)

        let connection: SQLiteConnection
        do {
            connection = try SQLiteConnection(fileURL: fileURL, readOnly: true)
        } catch {
            throw DatabaseValidationError.unreadable(error.localizedDescription)
        }

        var foundTables = Set<String>()
        do {
            try connection.query("SELECT name FROM sqlite_master WHERE type = 'table'") { statement in
                if let cString = sqlite3_column_text(statement, 0) {
                    foundTables.insert(String(cString: cString))
                }
            }
        } catch {
            throw DatabaseValidationError.unreadable(error.localizedDescription)
        }

        let missing = coreTables.filter { !foundTables.contains($0) }
        guard missing.isEmpty else {
            throw DatabaseValidationError.missingTables(missing)
        }
    }

    private static func removeStaleJournalFiles(for fileURL: URL) {
        let walURL = fileURL.deletingPathExtension().appendingPathExtension("db-wal")
        let shmURL = fileURL.deletingPathExtension().appendingPathExtension("db-shm")

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
