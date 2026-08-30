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

    /// Fetches all provinces from the lkp_provincia lookup table.
    /// Returns a sorted array of LookupProvince models (109 Italian provinces + EE for STATO ESTERO).
    /// Results are cached in the ViewModel.
    static func fetchProvinces(databaseFileURL: URL) throws -> [LookupProvince] {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        
        var provinces: [LookupProvince] = []
        try connection.query(
            """
            SELECT sigla, descrizione FROM lkp_provincia
            ORDER BY descrizione COLLATE NOCASE
            """
        ) { statement in
            let sigla = Self.stringValue(from: statement, columnIndex: 0) ?? ""
            let descrizione = Self.stringValue(from: statement, columnIndex: 1) ?? ""
            
            if !sigla.isEmpty && !descrizione.isEmpty {
                provinces.append(LookupProvince(sigla: sigla, descrizione: descrizione))
            }
        }
        
        AppLogger.info("✅ Loaded \(provinces.count) provinces from lkp_provincia")
        return provinces
    }

    /// Creates a new patient record in the database.
    /// Returns the ID of the inserted patient on success.
    /// Throws SQLiteConnectionError if the insert fails.
    static func createPatient(
        _ request: PatientCreateRequest,
        databaseFileURL: URL
    ) throws -> Int {
        AppLogger.info("Adding patient: \(request.nome) \(request.cognome)")
        
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: false)
        
        // Format date_nascita if provided
        var dateString: String? = nil
        if let date = request.data_nascita {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            dateString = formatter.string(from: date)
        }
        
        try connection.execute(
            """
            INSERT INTO paziente (
                cognome, nome, professione, indirizzo, citta, 
                telefono, cellulare, prov, cap, email, data_nascita
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                request.cognome,
                request.nome,
                request.professione ?? NSNull(),
                request.indirizzo ?? NSNull(),
                request.citta ?? NSNull(),
                request.telefono ?? NSNull(),
                request.cellulare ?? NSNull(),
                request.prov ?? NSNull(),
                request.cap ?? NSNull(),
                request.email ?? NSNull(),
                dateString ?? NSNull()
            ]
        )
        
        // Get the ID of the inserted row
        var lastID: Int = 0
        try connection.query("SELECT last_insert_rowid()") { statement in
            lastID = Int(sqlite3_column_int64(statement, 0))
        }
        
        AppLogger.info("✅ Patient created successfully: ID=\(lastID)")
        return lastID
    }
}
