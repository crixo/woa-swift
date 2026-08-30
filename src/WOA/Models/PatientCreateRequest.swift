import Foundation

/// Form input model for creating a new patient record.
/// Stores all fields as Swift types, with form-level string representation
/// that the ViewModel converts to database types.
struct PatientCreateRequest {
    var nome: String = ""
    var cognome: String = ""
    var professione: String?
    var indirizzo: String?
    var citta: String?
    var telefono: String?
    var cellulare: String?
    var prov: String?           // Stores sigla (AG, MI, etc.)
    var cap: String?
    var email: String?
    var data_nascita: Date?
}
