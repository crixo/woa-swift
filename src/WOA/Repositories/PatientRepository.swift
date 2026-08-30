import Foundation
import SQLite3

/// Queries the application database for patient records matching a partial name search.
enum PatientRepository {

    static func searchPatients(query: String, databaseFileURL: URL) throws -> [PatientSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return [] }

        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        let safeQuery = trimmed.lowercased().replacingOccurrences(of: "'", with: "''")
        let pattern = "%\(safeQuery)%"

        var matches: [PatientSearchResult] = []
        try connection.query(
            """
            SELECT
                p.ID,
                p.nome,
                p.cognome,
                p.data_nascita,
                p.indirizzo,
                p.citta,
                p.prov,
                COALESCE(lp.descrizione, p.prov) AS provincia
            FROM paziente p
            LEFT JOIN lkp_provincia lp ON LOWER(lp.sigla) = LOWER(p.prov)
            WHERE LOWER(p.nome) LIKE ? OR LOWER(p.cognome) LIKE ?
            ORDER BY p.cognome COLLATE NOCASE, p.nome COLLATE NOCASE
            LIMIT 200
            """,
            parameters: [pattern, pattern]
        ) { statement in
            let id = Int(sqlite3_column_int64(statement, 0))
            let nome = Self.stringValue(from: statement, columnIndex: 1) ?? ""
            let cognome = Self.stringValue(from: statement, columnIndex: 2) ?? ""
            let birthDate = Self.parseDate(from: statement, columnIndex: 3)
            let indirizzo = Self.stringValue(from: statement, columnIndex: 4)
            let citta = Self.stringValue(from: statement, columnIndex: 5)
            let prov = Self.stringValue(from: statement, columnIndex: 6)
            let provincia = Self.stringValue(from: statement, columnIndex: 7)

            matches.append(
                PatientSearchResult(
                    id: id,
                    nome: nome,
                    cognome: cognome,
                    dataNascita: birthDate,
                    indirizzo: indirizzo,
                    citta: citta,
                    provincia: provincia ?? prov
                )
            )
        }

        return matches
    }

    private static func stringValue(from statement: OpaquePointer, columnIndex: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, columnIndex) else { return nil }
        let value = String(cString: cString)
        return value.isEmpty ? nil : value
    }

    private static func parseDate(from statement: OpaquePointer, columnIndex: Int32) -> Date? {
        guard let raw = stringValue(from: statement, columnIndex: columnIndex) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatters = [
            ISO8601DateFormatter(),
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter
            }(),
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }()
        ]

        for formatter in formatters {
            if let iso = formatter as? ISO8601DateFormatter {
                if let date = iso.date(from: trimmed) { return date }
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso.date(from: trimmed) { return date }
            } else if let dateFormatter = formatter as? DateFormatter {
                if let date = dateFormatter.date(from: trimmed) { return date }
            }
        }

        return nil
    }
}
