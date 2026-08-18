import Foundation
import SQLite3

/// Queries the application database for table metadata and record counts.
enum TableRepository {

    /// Returns all user tables in the database at `fileURL`, sorted alphabetically, with record counts.
    static func fetchTableStats(fileURL: URL) throws -> [TableInfo] {
        let connection = try SQLiteConnection(fileURL: fileURL, readOnly: true)

        var tableNames: [String] = []
        try connection.query(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
        ) { statement in
            if let cString = sqlite3_column_text(statement, 0) {
                tableNames.append(String(cString: cString))
            }
        }

        var results: [TableInfo] = []
        for tableName in tableNames {
            let count = try recordCount(for: tableName, connection: connection)
            results.append(TableInfo(name: tableName, recordCount: count))
        }
        return results.sorted { $0.name < $1.name }
    }

    private static func recordCount(for tableName: String, connection: SQLiteConnection) throws -> Int {
        var count = 0
        // Table name comes from sqlite_master, not user input, so direct interpolation is safe here.
        try connection.query("SELECT COUNT(*) FROM \"\(tableName)\"") { statement in
            count = Int(sqlite3_column_int64(statement, 0))
        }
        return count
    }
}
