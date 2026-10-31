import XCTest
@testable import WOARegressionSubject

final class PatientRepositoryLifecycleTests: XCTestCase {
    func testCreatesReadsUpdatesAndDeletesPatientEntityGraph() throws {
        let databaseURL = try makeTemporaryDatabase()

        let patientID = try PatientRepository.createPatient(
            PatientCreateRequest(
                nome: "Ada",
                cognome: "Lovelace",
                professione: "Analyst",
                indirizzo: "1 St James Square",
                citta: "London",
                telefono: "111",
                cellulare: "222",
                prov: "MI",
                cap: "20100",
                email: "ada@example.test",
                data_nascita: Date(timeIntervalSince1970: 0)
            ),
            databaseFileURL: databaseURL
        )

        let createdPatient = try XCTUnwrap(
            PatientRepository.fetchPatient(by: patientID, databaseFileURL: databaseURL)
        )
        XCTAssertEqual(createdPatient.nome, "Ada")
        XCTAssertEqual(createdPatient.cognome, "Lovelace")
        XCTAssertEqual(createdPatient.professione, "Analyst")
        XCTAssertEqual(createdPatient.indirizzo, "1 St James Square")
        XCTAssertEqual(createdPatient.citta, "London")
        XCTAssertEqual(createdPatient.telefono, "111")
        XCTAssertEqual(createdPatient.cellulare, "222")
        XCTAssertEqual(createdPatient.prov, "MI")
        XCTAssertEqual(createdPatient.provincia, "MILANO")
        XCTAssertEqual(createdPatient.cap, "20100")
        XCTAssertEqual(createdPatient.email, "ada@example.test")
        XCTAssertNotNil(createdPatient.dataNascita)

        let consultationID = try PatientRepository.createConsultation(
            ConsultoRequest(patientID: patientID, initialProblem: "Initial complaint"),
            databaseFileURL: databaseURL
        )
        let remoteHistoryID = try PatientRepository.createRemoteHistory(
            RemoteHistoryCreateRequest(
                patientID: patientID,
                typeID: 1,
                description: "Initial history"
            ),
            databaseFileURL: databaseURL
        )
        let treatmentID = try PatientRepository.createTreatment(
            TreatmentCreateRequest(
                consultoID: consultationID,
                patientID: patientID,
                description: "Initial treatment"
            ),
            databaseFileURL: databaseURL
        )
        let evaluationID = try PatientRepository.createEvaluation(
            EvaluationCreateRequest(
                consultoID: consultationID,
                patientID: patientID,
                structural: "Initial structure",
                cranioSacral: "Initial cranio-sacral",
                akOrthodontic: "Initial orthodontic"
            ),
            databaseFileURL: databaseURL
        )
        let examID = try PatientRepository.createExam(
            ExamCreateRequest(
                consultoID: consultationID,
                patientID: patientID,
                typeID: 1,
                description: "Initial exam"
            ),
            databaseFileURL: databaseURL
        )

        XCTAssertEqual(
            try PatientRepository.fetchConsultations(for: patientID, databaseFileURL: databaseURL)
                .compactMap(\.initialProblem),
            ["Initial complaint"]
        )
        XCTAssertEqual(
            try XCTUnwrap(PatientRepository.fetchConsultation(by: consultationID, databaseFileURL: databaseURL))
                .patientID,
            patientID
        )
        XCTAssertEqual(
            try PatientRepository.fetchRemoteHistory(for: patientID, databaseFileURL: databaseURL)
                .compactMap(\.description),
            ["Initial history"]
        )
        XCTAssertEqual(
            try XCTUnwrap(PatientRepository.fetchRemoteHistoryItem(by: remoteHistoryID, databaseFileURL: databaseURL))
                .typeName,
            "incidente"
        )
        XCTAssertEqual(
            try PatientRepository.fetchTreatments(for: consultationID, databaseFileURL: databaseURL)
                .compactMap(\.description),
            ["Initial treatment"]
        )
        XCTAssertEqual(
            try XCTUnwrap(PatientRepository.fetchTreatment(by: treatmentID, databaseFileURL: databaseURL))
                .patientID,
            patientID
        )
        XCTAssertEqual(
            try PatientRepository.fetchEvaluations(for: consultationID, databaseFileURL: databaseURL)
                .compactMap(\.structural),
            ["Initial structure"]
        )
        XCTAssertEqual(
            try XCTUnwrap(PatientRepository.fetchEvaluation(by: evaluationID, databaseFileURL: databaseURL))
                .cranioSacral,
            "Initial cranio-sacral"
        )
        XCTAssertEqual(
            try PatientRepository.fetchExams(for: consultationID, databaseFileURL: databaseURL)
                .compactMap(\.description),
            ["Initial exam"]
        )
        XCTAssertEqual(
            try XCTUnwrap(PatientRepository.fetchExam(by: examID, databaseFileURL: databaseURL))
                .typeName,
            "visita specialistica"
        )

        try PatientRepository.updatePatient(
            PatientCreateRequest(
                nome: "Augusta",
                cognome: "King",
                professione: "Mathematician",
                indirizzo: "2 Updated Road",
                citta: "Oxford",
                telefono: "333",
                cellulare: "444",
                prov: "AG",
                cap: "00100",
                email: "augusta@example.test",
                data_nascita: Date(timeIntervalSince1970: 86_400)
            ),
            patientID: patientID,
            databaseFileURL: databaseURL
        )
        try PatientRepository.updateConsultation(
            ConsultoRequest(patientID: patientID, initialProblem: "Updated complaint"),
            consultationID: consultationID,
            databaseFileURL: databaseURL
        )
        try PatientRepository.updateRemoteHistory(
            RemoteHistoryCreateRequest(
                patientID: patientID,
                typeID: 2,
                description: "Updated history"
            ),
            id: remoteHistoryID,
            databaseFileURL: databaseURL
        )
        try PatientRepository.updateTreatment(
            TreatmentCreateRequest(
                consultoID: consultationID,
                patientID: patientID,
                description: "Updated treatment"
            ),
            id: treatmentID,
            databaseFileURL: databaseURL
        )
        try PatientRepository.updateEvaluation(
            EvaluationCreateRequest(
                consultoID: consultationID,
                patientID: patientID,
                structural: "Updated structure",
                cranioSacral: "Updated cranio-sacral",
                akOrthodontic: "Updated orthodontic"
            ),
            id: evaluationID,
            databaseFileURL: databaseURL
        )
        try PatientRepository.updateExam(
            ExamCreateRequest(
                consultoID: consultationID,
                patientID: patientID,
                typeID: 2,
                description: "Updated exam"
            ),
            id: examID,
            databaseFileURL: databaseURL
        )

        let updatedPatient = try XCTUnwrap(
            PatientRepository.fetchPatient(by: patientID, databaseFileURL: databaseURL)
        )
        XCTAssertEqual(updatedPatient.nome, "Augusta")
        XCTAssertEqual(updatedPatient.cognome, "King")
        XCTAssertEqual(updatedPatient.professione, "Mathematician")
        XCTAssertEqual(updatedPatient.indirizzo, "2 Updated Road")
        XCTAssertEqual(updatedPatient.citta, "Oxford")
        XCTAssertEqual(updatedPatient.telefono, "333")
        XCTAssertEqual(updatedPatient.cellulare, "444")
        XCTAssertEqual(updatedPatient.prov, "AG")
        XCTAssertEqual(updatedPatient.provincia, "AGRIGENTO")
        XCTAssertEqual(updatedPatient.cap, "00100")
        XCTAssertEqual(updatedPatient.email, "augusta@example.test")
        XCTAssertNotNil(updatedPatient.dataNascita)
        XCTAssertEqual(
            try XCTUnwrap(PatientRepository.fetchConsultation(by: consultationID, databaseFileURL: databaseURL))
                .initialProblem,
            "Updated complaint"
        )
        XCTAssertEqual(
            try XCTUnwrap(PatientRepository.fetchRemoteHistoryItem(by: remoteHistoryID, databaseFileURL: databaseURL))
                .description,
            "Updated history"
        )
        XCTAssertEqual(
            try XCTUnwrap(PatientRepository.fetchRemoteHistoryItem(by: remoteHistoryID, databaseFileURL: databaseURL))
                .typeName,
            "trauma"
        )
        XCTAssertEqual(
            try XCTUnwrap(PatientRepository.fetchTreatment(by: treatmentID, databaseFileURL: databaseURL))
                .description,
            "Updated treatment"
        )
        let updatedEvaluation = try XCTUnwrap(
            PatientRepository.fetchEvaluation(by: evaluationID, databaseFileURL: databaseURL)
        )
        XCTAssertEqual(updatedEvaluation.structural, "Updated structure")
        XCTAssertEqual(updatedEvaluation.cranioSacral, "Updated cranio-sacral")
        XCTAssertEqual(updatedEvaluation.akOrthodontic, "Updated orthodontic")
        let updatedExam = try XCTUnwrap(
            PatientRepository.fetchExam(by: examID, databaseFileURL: databaseURL)
        )
        XCTAssertEqual(updatedExam.description, "Updated exam")
        XCTAssertEqual(updatedExam.typeName, "rx")

        try PatientRepository.deleteExam(id: examID, databaseFileURL: databaseURL)
        try PatientRepository.deleteEvaluation(id: evaluationID, databaseFileURL: databaseURL)
        try PatientRepository.deleteTreatment(id: treatmentID, databaseFileURL: databaseURL)
        try PatientRepository.deleteRemoteHistory(id: remoteHistoryID, databaseFileURL: databaseURL)
        try PatientRepository.deleteConsultation(id: consultationID, databaseFileURL: databaseURL)
        try PatientRepository.deletePatient(id: patientID, databaseFileURL: databaseURL)

        XCTAssertNil(try PatientRepository.fetchPatient(by: patientID, databaseFileURL: databaseURL))
        XCTAssertNil(try PatientRepository.fetchConsultation(by: consultationID, databaseFileURL: databaseURL))
        XCTAssertNil(try PatientRepository.fetchRemoteHistoryItem(by: remoteHistoryID, databaseFileURL: databaseURL))
        XCTAssertNil(try PatientRepository.fetchTreatment(by: treatmentID, databaseFileURL: databaseURL))
        XCTAssertNil(try PatientRepository.fetchEvaluation(by: evaluationID, databaseFileURL: databaseURL))
        XCTAssertNil(try PatientRepository.fetchExam(by: examID, databaseFileURL: databaseURL))
        XCTAssertTrue(try PatientRepository.fetchConsultations(for: patientID, databaseFileURL: databaseURL).isEmpty)
        XCTAssertTrue(try PatientRepository.fetchRemoteHistory(for: patientID, databaseFileURL: databaseURL).isEmpty)
        XCTAssertTrue(try PatientRepository.fetchTreatments(for: consultationID, databaseFileURL: databaseURL).isEmpty)
        XCTAssertTrue(try PatientRepository.fetchEvaluations(for: consultationID, databaseFileURL: databaseURL).isEmpty)
        XCTAssertTrue(try PatientRepository.fetchExams(for: consultationID, databaseFileURL: databaseURL).isEmpty)
    }

    private func makeTemporaryDatabase() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appendingPathComponent("data/woa-empty.db")
        let databaseURL = directory.appendingPathComponent("lifecycle.sqlite")
        try FileManager.default.copyItem(at: sourceURL, to: databaseURL)

        let connection = try SQLiteConnection(fileURL: databaseURL)
        try connection.executeScript(
            """
            CREATE TABLE woa_auditing (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                entity_table TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                recorded_at TEXT NOT NULL,
                change_type TEXT NOT NULL
                    CHECK(change_type IN ('create', 'added', 'update', 'delete'))
            );
            """
        )
        return databaseURL
    }
}