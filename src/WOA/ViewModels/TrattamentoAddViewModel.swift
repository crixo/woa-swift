import Foundation


@MainActor final class TrattamentoAddViewModel: ModelFormValidator<TreatmentCreateRequest>, EntityAddViewModel {
    let consultoID: Int
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    @Published var formData: TreatmentCreateRequest
    @Published var errorMessage: String?
    @Published var shortErrorMessage: String?
    @Published var isSaving = false

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.consultoID = consultoID
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        formData = TreatmentCreateRequest(consultoID: consultoID, patientID: patientID)
        
        super.init(trigger: .onChangeAndSubmit)
        
        bindModel { [unowned self] in self.formData }
        register(\.description, rules: [.required("Description is required")])
    }

    func save() async -> Bool {
        guard validateAll() else { return false}
        isSaving = true
        do {
            let treatmentID = try PatientRepository.createTreatment(formData, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.treatmentCreated(treatmentID: treatmentID, consultoID: consultoID, databaseURL: databaseFileURL))
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}
