import SQLite3
import XCTest
@testable import WOARegressionSubject

final class SQLiteConnectionTests: XCTestCase {
    func testExecutesScriptAndBindsTextWithoutInterpretingSQL() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        let connection = try SQLiteConnection(fileURL: databaseURL)
        try connection.executeScript(
            """
            CREATE TABLE entries (id INTEGER PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE marker (id INTEGER PRIMARY KEY);
            """
        )
        let input = "value'); DROP TABLE marker; --"
        try connection.execute(
            "INSERT INTO entries (value) VALUES (?)",
            parameters: [.text(input)]
        )

        var storedValue: String?
        try connection.query("SELECT value FROM entries") { statement in
            guard let value = sqlite3_column_text(statement, 0) else {
                return XCTFail("Expected a text value")
            }
            storedValue = String(cString: value)
        }

        var markerExists = false
        try connection.query(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'marker'"
        ) { _ in markerExists = true }

        XCTAssertEqual(storedValue, input)
        XCTAssertTrue(markerExists)
    }

    func testThrowsForMalformedSQL() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        let connection = try SQLiteConnection(fileURL: databaseURL)

        XCTAssertThrowsError(try connection.execute("THIS IS NOT SQL"))
    }
}
