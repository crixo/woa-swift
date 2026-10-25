import Foundation

@MainActor final class EsameDetailEditViewModel: ModelFormValidator<ExamCreateRequest>, EntityDetailEditViewModel {
    let examID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    
    var entity: ExamDetail? { exam }//to comply the EntityDetailEditViewModel protocol
    @Published private(set) var exam: ExamDetail?
    @Published var formData: ExamCreateRequest
    @Published var types: [ExamType] = []
    @Published var errorMessage: String?
    @Published var shortErrorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published private(set) var saveSucceeded: Bool?

    init(examID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.examID = examID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        formData = ExamCreateRequest(consultoID: 0, patientID: 0)
        do {
            types = try PatientRepository.fetchExamTypes(databaseFileURL: databaseFileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        super.init(trigger: .onChangeAndSubmit)
        bindModel { [unowned self] in self.formData }
    }

    func load() async {
        isLoading = true
        do {
            exam = try PatientRepository.fetchExam(by: examID, databaseFileURL: databaseFileURL)
            if let exam {
                formData = ExamCreateRequest(
                    consultoID: exam.consultoID,
                    patientID: exam.patientID,
                    date: exam.date ?? Date(),
                    typeID: exam.typeID,
                    description: exam.description ?? ""
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        shortErrorMessage = nil
        do {
            try PatientRepository.updateExam(formData, id: examID, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.examUpdated(examID: examID, consultoID: formData.consultoID, databaseURL: databaseFileURL))
            saveSucceeded = true
            shortErrorMessage = nil
            isSaving = false
            return true
        } catch {
            let detailedMessage = error.localizedDescription
            let shortMessage = "The exam could not be saved. Please review the details and try again."
            AppLogger.error("Failed to save exam \(examID): \(detailedMessage)")
            errorMessage = detailedMessage
            shortErrorMessage = shortMessage
            saveSucceeded = false
            isSaving = false
            return false
        }
    }

    func delete() async -> Bool {
        isDeleting = true
        errorMessage = nil
        do {
            try PatientRepository.deleteExam(id: examID, databaseFileURL: databaseFileURL)
            if let exam {
                dataChangeCoordinator.publishChange(.examDeleted(examID: examID, consultoID: exam.consultoID, databaseURL: databaseFileURL))
            }
            isDeleting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
    }
}
