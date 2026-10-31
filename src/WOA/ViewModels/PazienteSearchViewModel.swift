import Foundation

/// Coordinates patient name searches and exposes the selected route payload without managing a modal sheet.
@MainActor
final class PazienteSearchViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published var results: [PatientSearchResult] = []
    @Published var isSearching: Bool = false
    @Published var isLoadingLastModifiedPatients: Bool = false
    @Published var selectedPatient: PatientSearchResult?
    @Published var errorMessage: String?
    @Published var lastModifiedPatients: [PatientAuditSummary] = []
    @Published var lastModifiedPatientsError: String?

    private let databasePath: String

    init(databasePath: String) {
        self.databasePath = databasePath
    }

    var resultCount: Int {
        results.count
    }

    func search() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            results = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil

        Task {
            do {
                let url = URL(fileURLWithPath: databasePath)
                let matches = try PatientRepository.searchPatients(query: trimmed, databaseFileURL: url)
                results = matches
                AppLogger.info("✅ Patient search returned \(matches.count) matches for query: \(trimmed)")
            } catch {
                results = []
                errorMessage = error.localizedDescription
                AppLogger.error("❌ Patient search failed: \(error.localizedDescription)")
            }

            isSearching = false
        }
    }

    func triggerSearchIfReady() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            results = []
            errorMessage = nil
            return
        }

        search()
    }

    func loadLastModifiedPatients() {
        isLoadingLastModifiedPatients = true
        lastModifiedPatientsError = nil

        Task {
            do {
                let url = URL(fileURLWithPath: databasePath)
                let patients = try AuditRepository.fetchLastModifiedPatients(
                    limit: AppSettings.AppConstants.lastModifiedPatientsLimit,
                    databaseFileURL: url
                )
                lastModifiedPatients = patients
                AppLogger.info("✅ Loaded \(patients.count) recent patient changes")
            } catch {
                lastModifiedPatients = []
                lastModifiedPatientsError = error.localizedDescription
                AppLogger.error("❌ Unable to load recent patient changes: \(error.localizedDescription)")
            }

            isLoadingLastModifiedPatients = false
        }
    }

    func openDetails(_ patient: PatientSearchResult) {
        selectedPatient = patient
    }

    func closeDetails() {
        selectedPatient = nil
    }
}
