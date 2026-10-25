import Foundation
import SQLite3

enum DatabaseMigrationRepositoryError: LocalizedError {
    case invalidRecord

    var errorDescription: String? {
        "The migration history contains an invalid record."
    }
}

enum DatabaseMigrationRepository {

    static let ledgerTableName = "woa_migration"

    static func ensureLedgerExists(using connection: SQLiteConnection) throws {
        try connection.execute(
            """
            CREATE TABLE IF NOT EXISTS \(ledgerTableName) (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                result TEXT NOT NULL CHECK (result IN ('success', 'failure')),
                error_message TEXT
            )
            """
        )
    }

    static func successfulMigrationIDs(using connection: SQLiteConnection) throws -> Set<String> {
        var identifiers = Set<String>()
        try connection.query("SELECT id FROM \(ledgerTableName) WHERE result = 'success'") { statement in
            guard let value = sqlite3_column_text(statement, 0) else {
                throw DatabaseMigrationRepositoryError.invalidRecord
            }
            identifiers.insert(String(cString: value))
        }
        return identifiers
    }

    static func record(
        _ migration: DatabaseMigration,
        errorMessage: String?,
        using connection: SQLiteConnection
    ) throws {
        try connection.execute(
            """
            INSERT INTO \(ledgerTableName) (id, name, timestamp, result, error_message)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                timestamp = excluded.timestamp,
                result = excluded.result,
                error_message = excluded.error_message
            """,
            parameters: [
                .text(migration.id),
                .text(migration.name),
                .integer(Int(migration.timestamp.timeIntervalSince1970 * 1_000)),
                .text(migration.result.rawValue),
                errorMessage.map(SQLiteValue.text) ?? .null
            ]
        )
    }

    static func fetchHistory(using connection: SQLiteConnection) throws -> [DatabaseMigration] {
        var migrations: [DatabaseMigration] = []
        try connection.query(
            "SELECT id, name, timestamp, result, error_message FROM \(ledgerTableName) ORDER BY timestamp DESC, id DESC"
        ) { statement in
            guard
                let idValue = sqlite3_column_text(statement, 0),
                let nameValue = sqlite3_column_text(statement, 1),
                let resultValue = sqlite3_column_text(statement, 3),
                let result = DatabaseMigrationResult(rawValue: String(cString: resultValue))
            else {
                throw DatabaseMigrationRepositoryError.invalidRecord
            }

            let errorMessage = sqlite3_column_text(statement, 4).map { String(cString: $0) }
            migrations.append(
                DatabaseMigration(
                    id: String(cString: idValue),
                    name: String(cString: nameValue),
                    timestamp: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 2)) / 1_000),
                    result: result,
                    errorMessage: errorMessage,
                    appliedInCurrentSession: false
                )
            )
        }
        return migrations
    }
}
