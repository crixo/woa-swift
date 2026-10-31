import XCTest
@testable import WOARegressionSubject

final class DatabaseValidatorTests: XCTestCase {
    func testAcceptsDatabaseWithAllRequiredTables() throws {
        let databaseURL = try makeTemporaryDatabase()
        let connection = try SQLiteConnection(fileURL: databaseURL)
        let statements = DatabaseValidator.coreTables
            .map { "CREATE TABLE \($0) (id INTEGER PRIMARY KEY);" }
            .joined(separator: "\n")
        try connection.executeScript(statements)

        XCTAssertNoThrow(try DatabaseValidator.validate(fileURL: databaseURL))
    }

    func testReportsEveryMissingCoreTableInExpectedOrder() throws {
        let databaseURL = try makeTemporaryDatabase()
        let connection = try SQLiteConnection(fileURL: databaseURL)
        try connection.execute("CREATE TABLE paziente (id INTEGER PRIMARY KEY)")

        XCTAssertThrowsError(try DatabaseValidator.validate(fileURL: databaseURL)) { error in
            guard case DatabaseValidationError.missingTables(let missingTables) = error else {
                return XCTFail("Expected missingTables error, got \(error)")
            }
            XCTAssertEqual(missingTables, DatabaseValidator.coreTables.filter { $0 != "paziente" })
        }
    }

    func testDoesNotCreateMissingDatabaseDuringValidation() throws {
        let databaseURL = try temporaryDatabaseURL()

        XCTAssertThrowsError(try DatabaseValidator.validate(fileURL: databaseURL)) { error in
            guard case DatabaseValidationError.unreadable = error else {
                return XCTFail("Expected unreadable error, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: databaseURL.path))
    }

    func testRejectsFileThatIsNotSQLite() throws {
        let databaseURL = try temporaryDatabaseURL()
        try Data("not a SQLite database".utf8).write(to: databaseURL)

        XCTAssertThrowsError(try DatabaseValidator.validate(fileURL: databaseURL)) { error in
            guard case DatabaseValidationError.unreadable = error else {
                return XCTFail("Expected unreadable error, got \(error)")
            }
        }
    }

    private func makeTemporaryDatabase() throws -> URL {
        let url = try temporaryDatabaseURL()
        _ = try SQLiteConnection(fileURL: url)
        return url
    }

    private func temporaryDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("test.sqlite")
    }
}
