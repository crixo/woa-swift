import Foundation
import SQLite3

/// Errors surfaced by SQLite connection operations.
enum SQLiteConnectionError: LocalizedError {
    case unableToOpen(path: String, message: String)
    case queryFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .unableToOpen(let path, let message):
            return "Unable to open database at \(path): \(message)"
        case .queryFailed(let message):
            return "SQL error: \(message)"
        }
    }
}

enum SQLiteValue {
    case text(String)
    case integer(Int)
    case null
}

/// Thin wrapper around a single SQLite3 connection with error-safe access.
final class SQLiteConnection {

    private var handle: OpaquePointer?

    init(fileURL: URL, readOnly: Bool = false) throws {
        let flags = readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        var db: OpaquePointer?
        let result = sqlite3_open_v2(fileURL.path, &db, flags, nil)
        guard result == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let db { sqlite3_close(db) }
            throw SQLiteConnectionError.unableToOpen(path: fileURL.path, message: message)
        }
        self.handle = db
    }

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    /// Executes a SQL statement with no result rows.
    func execute(_ sql: String) throws {
        _ = try execute(sql, parameters: [])
    }

    /// Executes a SQL statement with bound values and returns the affected row count.
    @discardableResult
    func execute(_ sql: String, parameters: [SQLiteValue]) throws -> Int {
        guard let handle else {
            throw SQLiteConnectionError.queryFailed(message: "connection closed")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            let message = String(cString: sqlite3_errmsg(handle))
            throw SQLiteConnectionError.queryFailed(message: message)
        }
        defer { sqlite3_finalize(statement) }

        try bind(parameters, to: statement, handle: handle)

        let step = sqlite3_step(statement)
        guard step == SQLITE_DONE || step == SQLITE_ROW else {
            let message = String(cString: sqlite3_errmsg(handle))
            throw SQLiteConnectionError.queryFailed(message: message)
        }

        return Int(sqlite3_changes(handle))
    }

    /// Executes a query, optionally binding a set of typed parameters before each row iteration.
    func query(_ sql: String, parameters: [SQLiteValue] = [], rowHandler: (OpaquePointer) throws -> Void) throws {
        guard let handle else {
            throw SQLiteConnectionError.queryFailed(message: "connection closed")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            let message = String(cString: sqlite3_errmsg(handle))
            throw SQLiteConnectionError.queryFailed(message: message)
        }
        defer { sqlite3_finalize(statement) }

        try bind(parameters, to: statement, handle: handle)

        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_ROW {
                try rowHandler(statement)
            } else if step == SQLITE_DONE {
                break
            } else {
                let message = String(cString: sqlite3_errmsg(handle))
                throw SQLiteConnectionError.queryFailed(message: message)
            }
        }
    }

    private func bind(_ parameters: [SQLiteValue], to statement: OpaquePointer, handle: OpaquePointer) throws {
        let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        for (index, parameter) in parameters.enumerated() {
            let parameterIndex = Int32(index + 1)
            let result: Int32
            switch parameter {
            case .text(let value):
                result = value.withCString { cString in
                    sqlite3_bind_text(statement, parameterIndex, cString, -1, sqliteTransient)
                }
            case .integer(let value):
                result = sqlite3_bind_int64(statement, parameterIndex, sqlite3_int64(value))
            case .null:
                result = sqlite3_bind_null(statement, parameterIndex)
            }

            guard result == SQLITE_OK else {
                let message = String(cString: sqlite3_errmsg(handle))
                throw SQLiteConnectionError.queryFailed(message: message)
            }
        }
    }
}
