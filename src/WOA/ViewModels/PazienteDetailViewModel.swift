import Foundation

@MainActor final class PazienteDetailViewModel: ObservableObject {
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator

    @Published private(set) var patient: PatientDetail?
    @Published private(set) var consultations: [ConsultationSummary] = []
    @Published private(set) var remoteHistory: [RemoteHistorySummary] = []
    @Published var editForm = PatientCreateRequest()
    @Published var provinces: [LookupProvince] = []
    @Published var validationErrors: [String: String] = [:]
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published var isAttributesExpanded = true
    @Published var isConsultationsExpanded = true
    @Published var isHistoryExpanded = true
    
    private var changeEventTask: Task<Void, Never>?

    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        
        // Subscribe to patient change events
        subscribeToChanges()
    }
    
    deinit {
        changeEventTask?.cancel()
    }
    
    private func subscribeToChanges() {
        changeEventTask?.cancel()
        changeEventTask = Task {
            for await _ in dataChangeCoordinator.subscribeToPatientChanges(patientID: patientID, databaseURL: databaseFileURL) {
                await load()
            }
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            patient = try PatientRepository.fetchPatient(by: patientID, databaseFileURL: databaseFileURL)
            consultations = try PatientRepository.fetchConsultations(for: patientID, databaseFileURL: databaseFileURL)
            remoteHistory = try PatientRepository.fetchRemoteHistory(for: patientID, databaseFileURL: databaseFileURL)
            provinces = try PatientRepository.fetchProvinces(databaseFileURL: databaseFileURL)
            if let patient {
                editForm = patient.formData
            }
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Failed to load patient \(patientID): \(error.localizedDescription)")
        }
        isLoading = false
    }

    func delete() async -> Bool {
        isDeleting = true
        errorMessage = nil
        do {
            try PatientRepository.deletePatient(id: patientID, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.patientDeleted(patientID: patientID, databaseURL: databaseFileURL))
            isDeleting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
    }
}




















