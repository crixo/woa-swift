import Foundation

@MainActor final class ConsultoDetailViewModel: ObservableObject {
    let consultoID: Int
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator

    var entity: ConsultationDetail? { consultation }
    @Published var errorMessage: String?
    @Published private(set) var consultation: ConsultationDetail?
    @Published private(set) var treatments: [TreatmentSummary] = []
    @Published private(set) var evaluations: [EvaluationSummary] = []
    @Published private(set) var exams: [ExamSummary] = []
    @Published var isLoading = false
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published var isTreatmentsExpanded = true
    @Published var isEvaluationsExpanded = true
    @Published var isExamsExpanded = true
    
    private var changeEventTask: Task<Void, Never>?

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.consultoID = consultoID
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator

        subscribeToChanges()
    }
    
    deinit {
        changeEventTask?.cancel()
    }
    
    private func subscribeToChanges() {
        changeEventTask?.cancel()
        changeEventTask = Task {
            for await _ in dataChangeCoordinator.subscribeToConsultoChanges(consultoID: consultoID, databaseURL: databaseFileURL) {
                await load()
            }
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            consultation = try PatientRepository.fetchConsultation(by: consultoID, databaseFileURL: databaseFileURL)
            treatments = try PatientRepository.fetchTreatments(for: consultoID, databaseFileURL: databaseFileURL)
            evaluations = try PatientRepository.fetchEvaluations(for: consultoID, databaseFileURL: databaseFileURL)
            exams = try PatientRepository.fetchExams(for: consultoID, databaseFileURL: databaseFileURL)
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Failed to load consulto \(consultoID): \(error.localizedDescription)")
        }
        isLoading = false
    }

    func delete() async -> Bool {
        isDeleting = true
        errorMessage = nil
        do {
            try PatientRepository.deleteConsultation(id: consultoID, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.consultationDeleted(consultationID: consultoID, patientID: patientID, databaseURL: databaseFileURL))
            isDeleting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
    }
}
