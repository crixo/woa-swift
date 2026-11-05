import Foundation
import SQLite3

enum AuditChangeType: String, Codable, Equatable {
    case create
    case added
    case update
    case delete
}

struct PatientAuditSummary: Identifiable, Equatable {
    let id: Int
    let fullName: String
    let changedAt: Date
}

enum AuditRepository {
    static func recordChange(
        entityTable: String,
        entityID: String,
        changeType: AuditChangeType,
        using connection: SQLiteConnection,
        timestamp: Date = Date()
    ) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try connection.execute(
            "INSERT INTO woa_auditing (entity_table, entity_id, recorded_at, change_type) VALUES (?, ?, ?, ?)",
            parameters: [
                .text(entityTable),
                .text(entityID),
                .text(formatter.string(from: timestamp)),
                .text(changeType.rawValue)
            ]
        )
    }

    static func fetchLastModifiedPatients(
        limit: Int = AppSettings.AppConstants.lastModifiedPatientsLimit,
        databaseFileURL: URL
    ) throws -> [PatientAuditSummary] {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        let sql = """
            WITH recent_changes AS (
                SELECT p.ID AS patient_id, p.cognome, p.nome, a.recorded_at AS changed_at
                FROM woa_auditing a
                JOIN paziente p ON a.entity_table = 'paziente' AND a.entity_id = CAST(p.ID AS TEXT)
                UNION ALL
                SELECT p.ID AS patient_id, p.cognome, p.nome, a.recorded_at AS changed_at
                FROM woa_auditing a
                JOIN consulto c ON a.entity_table = 'consulto' AND a.entity_id = CAST(c.ID AS TEXT)
                JOIN paziente p ON p.ID = c.ID_paziente
                UNION ALL
                SELECT p.ID AS patient_id, p.cognome, p.nome, a.recorded_at AS changed_at
                FROM woa_auditing a
                JOIN anamnesi_remota h ON a.entity_table = 'anamnesi_remota' AND a.entity_id = CAST(h.ID AS TEXT)
                JOIN paziente p ON p.ID = h.ID_paziente
                UNION ALL
                SELECT p.ID AS patient_id, p.cognome, p.nome, a.recorded_at AS changed_at
                FROM woa_auditing a
                JOIN trattamento t ON a.entity_table = 'trattamento' AND a.entity_id = CAST(t.ID AS TEXT)
                JOIN paziente p ON p.ID = t.ID_paziente
                UNION ALL
                SELECT p.ID AS patient_id, p.cognome, p.nome, a.recorded_at AS changed_at
                FROM woa_auditing a
                JOIN valutazione v ON a.entity_table = 'valutazione' AND a.entity_id = CAST(v.ID AS TEXT)
                JOIN paziente p ON p.ID = v.ID_paziente
                UNION ALL
                SELECT p.ID AS patient_id, p.cognome, p.nome, a.recorded_at AS changed_at
                FROM woa_auditing a
                JOIN esame e ON a.entity_table = 'esame' AND a.entity_id = CAST(e.ID AS TEXT)
                JOIN paziente p ON p.ID = e.ID_paziente
            )
            SELECT patient_id, cognome, nome, MAX(changed_at) AS changed_at
            FROM recent_changes
            GROUP BY patient_id, cognome, nome
            ORDER BY changed_at DESC
            LIMIT ?
            """

        var results: [PatientAuditSummary] = []
        try connection.query(sql, parameters: [.integer(limit)]) { statement in
            let id = Int(sqlite3_column_int64(statement, 0))
            let cognome = PatientRepository.stringValue(from: statement, columnIndex: 1) ?? ""
            let nome = PatientRepository.stringValue(from: statement, columnIndex: 2) ?? ""
            let changedAt = PatientRepository.parseDate(from: statement, columnIndex: 3) ?? Date()
            results.append(PatientAuditSummary(
                id: id,
                fullName: [nome, cognome].filter { !$0.isEmpty }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines),
                changedAt: changedAt
            ))
        }

        return results
    }
}

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
            parameters: [.text(pattern), .text(pattern)]
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

    fileprivate static func stringValue(from statement: OpaquePointer, columnIndex: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, columnIndex) else { return nil }
        let value = String(cString: cString)
        return value.isEmpty ? nil : value
    }

    fileprivate static func parseDate(from statement: OpaquePointer, columnIndex: Int32) -> Date? {
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

    private static func withAuditTransaction<Result>(
        databaseFileURL: URL,
        entityTable: String,
        changeType: AuditChangeType,
        mutation: (SQLiteConnection) throws -> (Result, String)
    ) throws -> Result {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: false)
        try connection.execute("BEGIN IMMEDIATE")

        do {
            let result = try mutation(connection)
            try AuditRepository.recordChange(
                entityTable: entityTable,
                entityID: result.1,
                changeType: changeType,
                using: connection
            )
            try connection.execute("COMMIT")
            return result.0
        } catch {
            do {
                try connection.execute("ROLLBACK")
            } catch {
                AppLogger.warning("Audit transaction rollback failed for \(entityTable): \(error.localizedDescription)")
            }
            throw error
        }
    }

    /// Creates a new patient record in the database.
    /// Returns the ID of the inserted patient on success.
    /// Throws SQLiteConnectionError if the insert fails.
    static func createPatient(
        _ request: PatientCreateRequest,
        databaseFileURL: URL
    ) throws -> Int {
        AppLogger.info("Adding patient")

        let dateString: String? = request.data_nascita.map { date in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }

        let insertSQL = """
        INSERT INTO paziente (
            cognome, nome, professione, indirizzo, citta,
            telefono, cellulare, prov, cap, email, data_nascita
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        let patientID: Int = try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "paziente",
            changeType: .added
        ) { connection in
            try connection.execute(
                insertSQL,
                parameters: [
                    .text(request.cognome),
                    .text(request.nome),
                    Self.value(request.professione),
                    Self.value(request.indirizzo),
                    Self.value(request.citta),
                    Self.value(request.telefono),
                    Self.value(request.cellulare),
                    Self.value(request.prov),
                    Self.value(request.cap),
                    Self.value(request.email),
                    Self.value(dateString)
                ]
            )

            let lastID = try lastInsertedID(from: connection)
            return (lastID, String(lastID))
        }

        AppLogger.info("✅ Patient created successfully: ID=\(patientID)")
        return patientID
    }

    static func fetchPatient(by id: Int, databaseFileURL: URL) throws -> PatientDetail? {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var patient: PatientDetail?
        try connection.query(
            """
            SELECT p.ID, p.cognome, p.nome, p.professione, p.indirizzo, p.citta,
                   p.telefono, p.cellulare, p.prov, p.cap, p.email, p.data_nascita,
                   COALESCE(lp.descrizione, p.prov)
            FROM paziente p
            LEFT JOIN lkp_provincia lp ON LOWER(lp.sigla) = LOWER(p.prov)
            WHERE p.ID = ?
            LIMIT 1
            """,
            parameters: [.integer(id)]
        ) { statement in
            patient = PatientDetail(
                id: Int(sqlite3_column_int64(statement, 0)),
                cognome: Self.stringValue(from: statement, columnIndex: 1) ?? "",
                nome: Self.stringValue(from: statement, columnIndex: 2) ?? "",
                professione: Self.stringValue(from: statement, columnIndex: 3),
                indirizzo: Self.stringValue(from: statement, columnIndex: 4),
                citta: Self.stringValue(from: statement, columnIndex: 5),
                telefono: Self.stringValue(from: statement, columnIndex: 6),
                cellulare: Self.stringValue(from: statement, columnIndex: 7),
                prov: Self.stringValue(from: statement, columnIndex: 8),
                cap: Self.stringValue(from: statement, columnIndex: 9),
                email: Self.stringValue(from: statement, columnIndex: 10),
                dataNascita: Self.parseDate(from: statement, columnIndex: 11),
                provincia: Self.stringValue(from: statement, columnIndex: 12)
            )
        }
        return patient
    }

    static func fetchConsultations(for patientID: Int, databaseFileURL: URL) throws -> [ConsultationSummary] {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var results: [ConsultationSummary] = []
        try connection.query(
            "SELECT ID, data, problema_iniziale FROM consulto WHERE ID_paziente = ? ORDER BY data DESC, ID DESC",
            parameters: [.integer(patientID)]
        ) { statement in
            results.append(ConsultationSummary(
                id: Int(sqlite3_column_int64(statement, 0)),
                date: Self.parseDate(from: statement, columnIndex: 1),
                initialProblem: Self.stringValue(from: statement, columnIndex: 2)
            ))
        }
        return results
    }

    static func fetchRemoteHistory(for patientID: Int, databaseFileURL: URL) throws -> [RemoteHistorySummary] {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var results: [RemoteHistorySummary] = []
        try connection.query(
            """
            SELECT h.ID, h.data, h.tipo, COALESCE(l.descrizione, ''), h.descrizione
            FROM anamnesi_remota h
            LEFT JOIN lkp_anamnesi l ON l.ID = h.tipo
            WHERE h.ID_paziente = ?
            ORDER BY h.data DESC, h.ID DESC
            """,
            parameters: [.integer(patientID)]
        ) { statement in
            results.append(RemoteHistorySummary(
                id: Int(sqlite3_column_int64(statement, 0)),
                date: Self.parseDate(from: statement, columnIndex: 1),
                typeID: Int(sqlite3_column_int64(statement, 2)),
                typeName: Self.stringValue(from: statement, columnIndex: 3),
                description: Self.stringValue(from: statement, columnIndex: 4)
            ))
        }
        return results
    }

    static func fetchConsultation(by id: Int, databaseFileURL: URL) throws -> ConsultationDetail? {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var result: ConsultationDetail?
        try connection.query(
            "SELECT ID, ID_paziente, data, problema_iniziale FROM consulto WHERE ID = ? LIMIT 1",
            parameters: [.integer(id)]
        ) { statement in
            result = ConsultationDetail(
                id: Int(sqlite3_column_int64(statement, 0)),
                patientID: Int(sqlite3_column_int64(statement, 1)),
                date: Self.parseDate(from: statement, columnIndex: 2),
                initialProblem: Self.stringValue(from: statement, columnIndex: 3)
            )
        }
        return result
    }

    static func fetchRemoteHistoryItem(by id: Int, databaseFileURL: URL) throws -> RemoteHistoryDetail? {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var result: RemoteHistoryDetail?
        try connection.query(
            """
            SELECT h.ID, h.ID_paziente, h.data, h.tipo, COALESCE(l.descrizione, ''), h.descrizione
            FROM anamnesi_remota h
            LEFT JOIN lkp_anamnesi l ON l.ID = h.tipo
            WHERE h.ID = ?
            LIMIT 1
            """,
            parameters: [.integer(id)]
        ) { statement in
            result = RemoteHistoryDetail(
                id: Int(sqlite3_column_int64(statement, 0)),
                patientID: Int(sqlite3_column_int64(statement, 1)),
                date: Self.parseDate(from: statement, columnIndex: 2),
                typeID: Int(sqlite3_column_int64(statement, 3)),
                typeName: Self.stringValue(from: statement, columnIndex: 4),
                description: Self.stringValue(from: statement, columnIndex: 5)
            )
        }
        return result
    }

    static func fetchAnamnesisTypes(databaseFileURL: URL) throws -> [AnamnesisType] {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var results: [AnamnesisType] = []
        try connection.query("SELECT ID, descrizione FROM lkp_anamnesi ORDER BY ID") { statement in
            results.append(AnamnesisType(
                id: Int(sqlite3_column_int64(statement, 0)),
                name: Self.stringValue(from: statement, columnIndex: 1) ?? "Not available"
            ))
        }
        return results
    }

    static func createConsultation(_ request: ConsultoRequest, databaseFileURL: URL) throws -> Int {
        return try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "consulto",
            changeType: .added
        ) { connection in
            try connection.execute(
                "INSERT INTO consulto (ID_paziente, data, problema_iniziale) VALUES (?, ?, ?)",
                parameters: [.integer(request.patientID), .text(Self.databaseDateTime(request.date)), .text(request.initialProblem)]
            )
            let id = try lastInsertedID(from: connection)
            return (id, String(id))
        }
    }

    static func createRemoteHistory(_ request: RemoteHistoryCreateRequest, databaseFileURL: URL) throws -> Int {
        return try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "anamnesi_remota",
            changeType: .added
        ) { connection in
            try connection.execute(
                "INSERT INTO anamnesi_remota (ID_paziente, data, tipo, descrizione) VALUES (?, ?, ?, ?)",
                parameters: [.integer(request.patientID), .text(Self.databaseDateTime(request.date)), .integer(request.typeID), Self.value(request.description)]
            )
            let id = try lastInsertedID(from: connection)
            return (id, String(id))
        }
    }

    static func updatePatient(_ request: PatientCreateRequest, patientID: Int, databaseFileURL: URL) throws {
        let sql = """
        UPDATE paziente SET cognome = ?, nome = ?, professione = ?, indirizzo = ?, citta = ?,
            telefono = ?, cellulare = ?, prov = ?, cap = ?, email = ?, data_nascita = ?
        WHERE ID = ?
        """
        let dateString = request.data_nascita.map(Self.databaseDate)

        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "paziente",
            changeType: .update
        ) { connection in
            let changes = try connection.execute(sql, parameters: [
                .text(request.cognome), .text(request.nome), Self.value(request.professione),
                Self.value(request.indirizzo), Self.value(request.citta), Self.value(request.telefono),
                Self.value(request.cellulare), Self.value(request.prov), Self.value(request.cap),
                Self.value(request.email), Self.value(dateString), .integer(patientID)
            ])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Patient ID \(patientID) was not updated")
            }
            return ((), String(patientID))
        }
    }

    static func deletePatient(id: Int, databaseFileURL: URL) throws {
        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "paziente",
            changeType: .delete
        ) { connection in
            let changes = try connection.execute("DELETE FROM paziente WHERE ID = ?", parameters: [.integer(id)])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Patient ID \(id) was not deleted")
            }
            return ((), String(id))
        }
    }

    // MARK: - Consultation Update/Delete
    
    static func updateConsultation(_ request: ConsultoRequest, consultationID: Int, databaseFileURL: URL) throws {
        let sql = """
        UPDATE consulto SET ID_paziente = ?, data = ?, problema_iniziale = ?
        WHERE ID = ?
        """
        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "consulto",
            changeType: .update
        ) { connection in
            let changes = try connection.execute(sql, parameters: [
                .integer(request.patientID),
                .text(Self.databaseDateTime(request.date)),
                .text(request.initialProblem),
                .integer(consultationID)
            ])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Consultation ID \(consultationID) was not updated")
            }
            return ((), String(consultationID))
        }
    }

    static func deleteConsultation(id: Int, databaseFileURL: URL) throws {
        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "consulto",
            changeType: .delete
        ) { connection in
            let changes = try connection.execute("DELETE FROM consulto WHERE ID = ?", parameters: [.integer(id)])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Consultation ID \(id) was not deleted")
            }
            return ((), String(id))
        }
    }

    // MARK: - Remote History Update/Delete
    
    static func updateRemoteHistory(_ request: RemoteHistoryCreateRequest, id: Int, databaseFileURL: URL) throws {
        let sql = """
        UPDATE anamnesi_remota SET ID_paziente = ?, data = ?, tipo = ?, descrizione = ?
        WHERE ID = ?
        """
        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "anamnesi_remota",
            changeType: .update
        ) { connection in
            let changes = try connection.execute(sql, parameters: [
                .integer(request.patientID),
                .text(Self.databaseDateTime(request.date)),
                .integer(request.typeID),
                Self.value(request.description),
                .integer(id)
            ])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Remote history ID \(id) was not updated")
            }
            return ((), String(id))
        }
    }

    static func deleteRemoteHistory(id: Int, databaseFileURL: URL) throws {
        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "anamnesi_remota",
            changeType: .delete
        ) { connection in
            let changes = try connection.execute("DELETE FROM anamnesi_remota WHERE ID = ?", parameters: [.integer(id)])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Remote history ID \(id) was not deleted")
            }
            return ((), String(id))
        }
    }

    // MARK: - Treatment CRUD
    
    static func fetchTreatments(for consultoID: Int, databaseFileURL: URL) throws -> [TreatmentSummary] {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var results: [TreatmentSummary] = []
        try connection.query(
            "SELECT ID, data, descrizione FROM trattamento WHERE ID_consulto = ? ORDER BY data DESC, ID DESC",
            parameters: [.integer(consultoID)]
        ) { statement in
            results.append(TreatmentSummary(
                id: Int(sqlite3_column_int64(statement, 0)),
                date: Self.parseDate(from: statement, columnIndex: 1),
                description: Self.stringValue(from: statement, columnIndex: 2)
            ))
        }
        return results
    }

    static func fetchTreatment(by id: Int, databaseFileURL: URL) throws -> TreatmentDetail? {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var result: TreatmentDetail?
        try connection.query(
            "SELECT ID, ID_consulto, ID_paziente, data, descrizione FROM trattamento WHERE ID = ? LIMIT 1",
            parameters: [.integer(id)]
        ) { statement in
            result = TreatmentDetail(
                id: Int(sqlite3_column_int64(statement, 0)),
                consultoID: Int(sqlite3_column_int64(statement, 1)),
                patientID: Int(sqlite3_column_int64(statement, 2)),
                date: Self.parseDate(from: statement, columnIndex: 3),
                description: Self.stringValue(from: statement, columnIndex: 4)
            )
        }
        return result
    }

    static func createTreatment(_ request: TreatmentCreateRequest, databaseFileURL: URL) throws -> Int {
        return try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "trattamento",
            changeType: .added
        ) { connection in
            try connection.execute(
                "INSERT INTO trattamento (ID_consulto, ID_paziente, data, descrizione) VALUES (?, ?, ?, ?)",
                parameters: [
                    .integer(request.consultoID),
                    .integer(request.patientID),
                    .text(Self.databaseDateTime(request.date)),
                    .text(request.description)
                ]
            )
            let id = try lastInsertedID(from: connection)
            return (id, String(id))
        }
    }

    static func updateTreatment(_ request: TreatmentCreateRequest, id: Int, databaseFileURL: URL) throws {
        let sql = """
        UPDATE trattamento SET ID_consulto = ?, ID_paziente = ?, data = ?, descrizione = ?
        WHERE ID = ?
        """
        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "trattamento",
            changeType: .update
        ) { connection in
            let changes = try connection.execute(sql, parameters: [
                .integer(request.consultoID),
                .integer(request.patientID),
                .text(Self.databaseDateTime(request.date)),
                .text(request.description),
                .integer(id)
            ])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Treatment ID \(id) was not updated")
            }
            return ((), String(id))
        }
    }

    static func deleteTreatment(id: Int, databaseFileURL: URL) throws {
        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "trattamento",
            changeType: .delete
        ) { connection in
            let changes = try connection.execute("DELETE FROM trattamento WHERE ID = ?", parameters: [.integer(id)])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Treatment ID \(id) was not deleted")
            }
            return ((), String(id))
        }
    }

    // MARK: - Evaluation CRUD
    
    static func fetchEvaluations(for consultoID: Int, databaseFileURL: URL) throws -> [EvaluationSummary] {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var results: [EvaluationSummary] = []
        try connection.query(
            "SELECT ID, strutturale, cranio_sacrale, ak_ortodontica FROM valutazione WHERE ID_consulto = ? ORDER BY ID DESC",
            parameters: [.integer(consultoID)]
        ) { statement in
            results.append(EvaluationSummary(
                id: Int(sqlite3_column_int64(statement, 0)),
                structural: Self.stringValue(from: statement, columnIndex: 1),
                cranioSacral: Self.stringValue(from: statement, columnIndex: 2),
                akOrthodontic: Self.stringValue(from: statement, columnIndex: 3)
            ))
        }
        return results
    }

    static func fetchEvaluation(by id: Int, databaseFileURL: URL) throws -> EvaluationDetail? {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var result: EvaluationDetail?
        try connection.query(
            "SELECT ID, ID_consulto, ID_paziente, strutturale, cranio_sacrale, ak_ortodontica FROM valutazione WHERE ID = ? LIMIT 1",
            parameters: [.integer(id)]
        ) { statement in
            result = EvaluationDetail(
                id: Int(sqlite3_column_int64(statement, 0)),
                consultoID: Int(sqlite3_column_int64(statement, 1)),
                patientID: Int(sqlite3_column_int64(statement, 2)),
                structural: Self.stringValue(from: statement, columnIndex: 3),
                cranioSacral: Self.stringValue(from: statement, columnIndex: 4),
                akOrthodontic: Self.stringValue(from: statement, columnIndex: 5)
            )
        }
        return result
    }

    static func createEvaluation(_ request: EvaluationCreateRequest, databaseFileURL: URL) throws -> Int {
        return try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "valutazione",
            changeType: .added
        ) { connection in
            try connection.execute(
                "INSERT INTO valutazione (ID_consulto, ID_paziente, strutturale, cranio_sacrale, ak_ortodontica) VALUES (?, ?, ?, ?, ?)",
                parameters: [
                    .integer(request.consultoID),
                    .integer(request.patientID),
                    .text(request.structural),
                    .text(request.cranioSacral),
                    .text(request.akOrthodontic)
                ]
            )
            let id = try lastInsertedID(from: connection)
            return (id, String(id))
        }
    }

    static func updateEvaluation(_ request: EvaluationCreateRequest, id: Int, databaseFileURL: URL) throws {
        let sql = """
        UPDATE valutazione SET ID_consulto = ?, ID_paziente = ?, strutturale = ?, cranio_sacrale = ?, ak_ortodontica = ?
        WHERE ID = ?
        """
        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "valutazione",
            changeType: .update
        ) { connection in
            let changes = try connection.execute(sql, parameters: [
                .integer(request.consultoID),
                .integer(request.patientID),
                .text(request.structural),
                .text(request.cranioSacral),
                .text(request.akOrthodontic),
                .integer(id)
            ])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Evaluation ID \(id) was not updated")
            }
            return ((), String(id))
        }
    }

    static func deleteEvaluation(id: Int, databaseFileURL: URL) throws {
        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "valutazione",
            changeType: .delete
        ) { connection in
            let changes = try connection.execute("DELETE FROM valutazione WHERE ID = ?", parameters: [.integer(id)])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Evaluation ID \(id) was not deleted")
            }
            return ((), String(id))
        }
    }

    // MARK: - Exam CRUD
    
    static func fetchExams(for consultoID: Int, databaseFileURL: URL) throws -> [ExamSummary] {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var results: [ExamSummary] = []
        try connection.query(
            """
            SELECT e.ID, e.data, COALESCE(l.descrizione, ''), e.descrizione
            FROM esame e
            LEFT JOIN lkp_esame l ON l.ID = e.tipo
            WHERE e.ID_consulto = ?
            ORDER BY e.data DESC, e.ID DESC
            """,
            parameters: [.integer(consultoID)]
        ) { statement in
            results.append(ExamSummary(
                id: Int(sqlite3_column_int64(statement, 0)),
                date: Self.parseDate(from: statement, columnIndex: 1),
                typeName: Self.stringValue(from: statement, columnIndex: 2),
                description: Self.stringValue(from: statement, columnIndex: 3)
            ))
        }
        return results
    }

    static func fetchExam(by id: Int, databaseFileURL: URL) throws -> ExamDetail? {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var result: ExamDetail?
        try connection.query(
            """
            SELECT e.ID, e.ID_consulto, e.ID_paziente, e.data, e.tipo, COALESCE(l.descrizione, ''), e.descrizione
            FROM esame e
            LEFT JOIN lkp_esame l ON l.ID = e.tipo
            WHERE e.ID = ?
            LIMIT 1
            """,
            parameters: [.integer(id)]
        ) { statement in
            result = ExamDetail(
                id: Int(sqlite3_column_int64(statement, 0)),
                consultoID: Int(sqlite3_column_int64(statement, 1)),
                patientID: Int(sqlite3_column_int64(statement, 2)),
                date: Self.parseDate(from: statement, columnIndex: 3),
                typeID: Int(sqlite3_column_int64(statement, 4)),
                typeName: Self.stringValue(from: statement, columnIndex: 5),
                description: Self.stringValue(from: statement, columnIndex: 6)
            )
        }
        return result
    }

    static func fetchExamTypes(databaseFileURL: URL) throws -> [ExamType] {
        let connection = try SQLiteConnection(fileURL: databaseFileURL, readOnly: true)
        var results: [ExamType] = []
        try connection.query("SELECT ID, descrizione FROM lkp_esame ORDER BY ID") { statement in
            results.append(ExamType(
                id: Int(sqlite3_column_int64(statement, 0)),
                name: Self.stringValue(from: statement, columnIndex: 1) ?? "Not available"
            ))
        }
        return results
    }

    static func createExam(_ request: ExamCreateRequest, databaseFileURL: URL) throws -> Int {
        return try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "esame",
            changeType: .added
        ) { connection in
            try connection.execute(
                "INSERT INTO esame (ID_consulto, ID_paziente, data, tipo, descrizione) VALUES (?, ?, ?, ?, ?)",
                parameters: [
                    .integer(request.consultoID),
                    .integer(request.patientID),
                    .text(Self.databaseDateTime(request.date)),
                    .integer(request.typeID),
                    .text(request.description)
                ]
            )
            let id = try lastInsertedID(from: connection)
            return (id, String(id))
        }
    }

    static func updateExam(_ request: ExamCreateRequest, id: Int, databaseFileURL: URL) throws {
        let sql = """
        UPDATE esame SET ID_consulto = ?, ID_paziente = ?, data = ?, tipo = ?, descrizione = ?
        WHERE ID = ?
        """
        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "esame",
            changeType: .update
        ) { connection in
            let changes = try connection.execute(sql, parameters: [
                .integer(request.consultoID),
                .integer(request.patientID),
                .text(Self.databaseDateTime(request.date)),
                .integer(request.typeID),
                .text(request.description),
                .integer(id)
            ])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Exam ID \(id) was not updated")
            }
            return ((), String(id))
        }
    }

    static func deleteExam(id: Int, databaseFileURL: URL) throws {
        try withAuditTransaction(
            databaseFileURL: databaseFileURL,
            entityTable: "esame",
            changeType: .delete
        ) { connection in
            let changes = try connection.execute("DELETE FROM esame WHERE ID = ?", parameters: [.integer(id)])
            guard changes == 1 else {
                throw SQLiteConnectionError.queryFailed(message: "Exam ID \(id) was not deleted")
            }
            return ((), String(id))
        }
    }

    private static func value(_ value: String?) -> SQLiteValue {
        value.map(SQLiteValue.text) ?? .null
    }

    private static func databaseDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func databaseDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private static func lastInsertedID(from connection: SQLiteConnection) throws -> Int {
        var lastID = 0
        try connection.query("SELECT last_insert_rowid()") { statement in
            lastID = Int(sqlite3_column_int64(statement, 0))
        }
        return lastID
    }
}
