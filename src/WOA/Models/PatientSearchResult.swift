import Foundation

/// Lightweight patient model used for search results and details popups.
struct PatientSearchResult: Identifiable, Equatable {
    let id: Int
    let nome: String
    let cognome: String
    let dataNascita: Date?
    let indirizzo: String?
    let citta: String?
    let provincia: String?

    var fullName: String {
        [nome, cognome]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var age: Int? {
        guard let dataNascita else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let ageComponents = calendar.dateComponents([.year], from: dataNascita, to: Date())
        return ageComponents.year
    }

    var ageText: String {
        guard let age else { return "Age unavailable" }
        return "\(age) years"
    }

    var address: String {
        let pieces = [indirizzo, citta, provincia]
            .compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        return pieces.joined(separator: ", ")
    }

    var details: [String] {
        [
            "Name: \(fullName)",
            "Age: \(ageText)",
            "Address: \(address.isEmpty ? "Not available" : address)",
            "Birth date: \(birthDateText)"
        ]
    }

    private var birthDateText: String {
        guard let dataNascita else { return "Not available" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: dataNascita)
    }
}
