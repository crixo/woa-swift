import Foundation

struct PatientDetail: Identifiable, Hashable {
    let id: Int
    var cognome: String
    var nome: String
    var professione: String?
    var indirizzo: String?
    var citta: String?
    var telefono: String?
    var cellulare: String?
    var prov: String?
    var cap: String?
    var email: String?
    var dataNascita: Date?
    var provincia: String?

    var fullName: String {
        "\(nome) \(cognome)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var ageText: String {
        guard let dataNascita else { return "Not available" }
        let years = Calendar.current.dateComponents([.year], from: dataNascita, to: Date()).year ?? 0
        return years >= 0 ? "\(years)" : "Not available"
    }

    var formData: PatientCreateRequest {
        PatientCreateRequest(
            nome: nome,
            cognome: cognome,
            professione: professione,
            indirizzo: indirizzo,
            citta: citta,
            telefono: telefono,
            cellulare: cellulare,
            prov: prov,
            cap: cap,
            email: email,
            data_nascita: dataNascita
        )
    }
}

struct ConsultationSummary: Identifiable, Hashable {
    let id: Int
    let date: Date?
    let initialProblem: String?
}

struct ConsultationDetail: Identifiable, Hashable {
    let id: Int
    let patientID: Int
    var date: Date?
    var initialProblem: String?
}

struct ConsultationCreateRequest: Hashable {
    var patientID: Int
    var date: Date = Date()
    var initialProblem: String = ""
}

struct RemoteHistorySummary: Identifiable, Hashable {
    let id: Int
    let date: Date?
    let typeID: Int
    let typeName: String?
    let description: String?
}

struct RemoteHistoryDetail: Identifiable, Hashable {
    let id: Int
    let patientID: Int
    var date: Date?
    var typeID: Int
    var typeName: String?
    var description: String?
}

struct AnamnesisType: Identifiable, Hashable {
    let id: Int
    let name: String
}

struct RemoteHistoryCreateRequest: Hashable {
    var patientID: Int
    var date: Date = Date()
    var typeID: Int = 1
    var description: String = ""
}
