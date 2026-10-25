import Foundation

enum DatabaseMigrationError: LocalizedError {
    case migrationFolderMissing
    case invalidFilename(String)
    case duplicateIdentifier(String)
    case unableToReadScript(String, String)
    case migrationFailed(name: String, message: String)
    case rollbackFailed(name: String, migrationMessage: String, rollbackMessage: String)
    case unableToRecordFailure(name: String, migrationMessage: String, recordMessage: String)

    var errorDescription: String? {
        switch self {
        case .migrationFolderMissing:
            return "The bundled database migrations folder is missing. Reinstall the application and try again."
        case .invalidFilename(let name):
            return "Migration file '\(name)' must start with a numeric identifier followed by '_' or '-'."
        case .duplicateIdentifier(let id):
            return "More than one migration uses the identifier '\(id)'. Give each migration a unique numeric prefix."
        case .unableToReadScript(let name, let message):
            return "Unable to read migration '\(name)': \(message)"
        case .migrationFailed(let name, let message):
            return "Migration '\(name)' failed: \(message)"
        case .rollbackFailed(let name, let migrationMessage, let rollbackMessage):
            return "Migration '\(name)' failed (\(migrationMessage)) and its transaction could not be rolled back (\(rollbackMessage))."
        case .unableToRecordFailure(let name, let migrationMessage, let recordMessage):
            return "Migration '\(name)' failed (\(migrationMessage)); its failure could not be recorded (\(recordMessage))."
        }
    }
}

@MainActor
final class DatabaseMigrationService: ObservableObject {

    private(set) var appliedMigrationIDsThisSession = Set<String>()
    private let migrationsDirectoryURL: URL?

    init(migrationsDirectoryURL: URL? = nil) {
        self.migrationsDirectoryURL = migrationsDirectoryURL
    }

    func applyPendingMigrations(to databaseURL: URL) async throws {
        let folderURL: URL
        if let migrationsDirectoryURL {
            folderURL = migrationsDirectoryURL
        } else if let bundledFolderURL = Bundle.main.url(forResource: "migrations", withExtension: nil) {
            folderURL = bundledFolderURL
        } else {
            throw DatabaseMigrationError.migrationFolderMissing
        }

        do {
            let appliedIdentifiers = try await Task.detached(priority: .userInitiated) {
                try Self.runPendingMigrations(databaseURL: databaseURL, migrationsFolderURL: folderURL)
            }.value
            appliedMigrationIDsThisSession.formUnion(appliedIdentifiers)
        } catch let failure as MigrationBatchFailure {
            appliedMigrationIDsThisSession.formUnion(failure.successfulMigrationIDs)
            throw failure
        }
    }

    func migrationHistory(for databaseURL: URL) async throws -> [DatabaseMigration] {
        let appliedIdentifiers = appliedMigrationIDsThisSession
        return try await Task.detached(priority: .userInitiated) {
            try Self.loadHistory(databaseURL: databaseURL, appliedIdentifiers: appliedIdentifiers)
        }.value
    }

    nonisolated private static func runPendingMigrations(
        databaseURL: URL,
        migrationsFolderURL: URL
    ) throws -> [String] {
        let migrations = try loadScripts(from: migrationsFolderURL)
        let connection = try SQLiteConnection(fileURL: databaseURL, createIfMissing: false)
        try DatabaseMigrationRepository.ensureLedgerExists(using: connection)
        let successfulIdentifiers = try DatabaseMigrationRepository.successfulMigrationIDs(using: connection)
        var appliedIdentifiers: [String] = []

        for migration in migrations {
            if successfulIdentifiers.contains(migration.id) {
                AppLogger.info("Database migration skipped because it was already applied: \(migration.name)")
                continue
            }

            let appliedAt = Date()
            let record = DatabaseMigration(
                id: migration.id,
                name: migration.name,
                timestamp: appliedAt,
                result: .success,
                errorMessage: nil,
                appliedInCurrentSession: true
            )

            do {
                try connection.execute("BEGIN IMMEDIATE")
                try connection.executeScript(migration.sql)
                try DatabaseMigrationRepository.record(record, errorMessage: nil, using: connection)
                try connection.execute("COMMIT")
                appliedIdentifiers.append(migration.id)
                AppLogger.info("Database migration succeeded: \(migration.name) at \(appliedAt.formatted(.iso8601))")
            } catch {
                let migrationMessage = error.localizedDescription
                do {
                    try connection.execute("ROLLBACK")
                } catch {
                    throw MigrationBatchFailure(
                        successfulMigrationIDs: appliedIdentifiers,
                        message: DatabaseMigrationError.rollbackFailed(
                            name: migration.name,
                            migrationMessage: migrationMessage,
                            rollbackMessage: error.localizedDescription
                        ).localizedDescription
                    )
                }

                do {
                    let failureRecord = DatabaseMigration(
                        id: migration.id,
                        name: migration.name,
                        timestamp: Date(),
                        result: .failure,
                        errorMessage: migrationMessage,
                        appliedInCurrentSession: false
                    )
                    try DatabaseMigrationRepository.record(
                        failureRecord,
                        errorMessage: migrationMessage,
                        using: connection
                    )
                } catch {
                    throw MigrationBatchFailure(
                        successfulMigrationIDs: appliedIdentifiers,
                        message: DatabaseMigrationError.unableToRecordFailure(
                            name: migration.name,
                            migrationMessage: migrationMessage,
                            recordMessage: error.localizedDescription
                        ).localizedDescription
                    )
                }

                AppLogger.error("Database migration failed: \(migration.name): \(migrationMessage)")
                throw MigrationBatchFailure(
                    successfulMigrationIDs: appliedIdentifiers,
                    message: DatabaseMigrationError.migrationFailed(
                        name: migration.name,
                        message: migrationMessage
                    ).localizedDescription
                )
            }
        }

        return appliedIdentifiers
    }

    nonisolated private static func loadHistory(
        databaseURL: URL,
        appliedIdentifiers: Set<String>
    ) throws -> [DatabaseMigration] {
        let connection = try SQLiteConnection(fileURL: databaseURL, readOnly: true)
        guard try migrationLedgerExists(using: connection) else { return [] }
        return try DatabaseMigrationRepository.fetchHistory(using: connection).map { migration in
            var migration = migration
            migration.appliedInCurrentSession = appliedIdentifiers.contains(migration.id)
                && migration.result == .success
            return migration
        }
    }

    nonisolated private static func migrationLedgerExists(using connection: SQLiteConnection) throws -> Bool {
        var exists = false
        try connection.query(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
            parameters: [.text(DatabaseMigrationRepository.ledgerTableName)]
        ) { _ in exists = true }
        return exists
    }

    nonisolated private static func loadScripts(from folderURL: URL) throws -> [MigrationScript] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let scriptURLs = urls.filter { $0.pathExtension.lowercased() == "sql" }
        var scripts: [MigrationScript] = []
        var numericIdentifiers = Set<Int>()

        for url in scriptURLs {
            let filename = url.lastPathComponent
            guard let separatorIndex = filename.firstIndex(where: { $0 == "_" || $0 == "-" }) else {
                throw DatabaseMigrationError.invalidFilename(filename)
            }
            let identifier = String(filename[..<separatorIndex])
            guard
                !identifier.isEmpty,
                identifier.utf8.allSatisfy({ (48...57).contains($0) }),
                let order = Int(identifier)
            else {
                throw DatabaseMigrationError.invalidFilename(filename)
            }
            guard numericIdentifiers.insert(order).inserted else {
                throw DatabaseMigrationError.duplicateIdentifier(identifier)
            }

            do {
                let sql = try String(contentsOf: url, encoding: .utf8)
                scripts.append(MigrationScript(id: identifier, order: order, name: filename, sql: sql))
            } catch {
                throw DatabaseMigrationError.unableToReadScript(filename, error.localizedDescription)
            }
        }

        return scripts.sorted {
            $0.order < $1.order
        }
    }
}

private struct MigrationScript {
    let id: String
    let order: Int
    let name: String
    let sql: String
}

private struct MigrationBatchFailure: LocalizedError, Sendable {
    let successfulMigrationIDs: [String]
    let message: String

    var errorDescription: String? { message }
}
