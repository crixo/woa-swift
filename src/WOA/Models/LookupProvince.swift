import Foundation

/// Lightweight model representing a province (provincia) from the lkp_provincia lookup table.
/// Used to populate the province dropdown in the AddPatientView form.
struct LookupProvince: Identifiable, Hashable {
    let id: UUID = UUID()
    let sigla: String          // AG, MI, etc. — stored in paziente.prov
    let descrizione: String    // AGRIGENTO, MILANO, etc. — displayed to user
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(sigla)
    }
    
    static func == (lhs: LookupProvince, rhs: LookupProvince) -> Bool {
        lhs.sigla == rhs.sigla
    }
}
