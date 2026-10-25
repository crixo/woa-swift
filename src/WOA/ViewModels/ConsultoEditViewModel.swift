import Foundation

@MainActor final class ConsultoEditViewModel: ModelFormValidator<ConsultoRequest>, EntityEditViewModel {
    let consultoID: Int
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    
    @Published private(set) var entity: ConsultationDetail?
    @Published var formData = ConsultoRequest(patientID: 0)
    @Published var errorMessage: String?
    @Published var shortErrorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var isEditing = false
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
        formData = ConsultoRequest(patientID: patientID)
        
        super.init(trigger: .onChangeAndSubmit)
        bindModel { [unowned self] in self.formData }
        register(\.initialProblem, rules: [.required("Problema inziale e' obbligatorio")])
        
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            entity = try PatientRepository.fetchConsultation(by: consultoID, databaseFileURL: databaseFileURL)
            if let entity {
                formData = ConsultoRequest(patientID: entity.patientID, date: entity.date ?? Date(), initialProblem: entity.initialProblem ?? "")
            }
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Failed to load consulto \(consultoID): \(error.localizedDescription)")
        }
        isLoading = false
    }

//    func beginEditing() {
//        guard let entity else { return }
//        formData = ConsultoRequest(patientID: entity.patientID, date: entity.date ?? Date(), initialProblem: entity.initialProblem ?? "")
//        isEditing = true
//    }
//
//    func cancelEditing() {
//        if let entity {
//            formData = ConsultoRequest(patientID: entity.patientID, date: entity.date ?? Date(), initialProblem: entity.initialProblem ?? "")
//        }
//        isEditing = false
//    }

    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        do {
            try PatientRepository.updateConsultation(formData, consultationID: consultoID, databaseFileURL: databaseFileURL)
            isEditing = false
            dataChangeCoordinator.publishChange(.consultationUpdated(consultationID: consultoID, patientID: patientID, databaseURL: databaseFileURL))
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
        
        return errorMessage == nil
    }
}
