import Foundation

@MainActor final class AnamnesiRemotaAddViewModel: ModelFormValidator<RemoteHistoryCreateRequest>, EntityAddViewModel  {
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    @Published var formData: RemoteHistoryCreateRequest
    @Published var types: [AnamnesisType] = []
    @Published var errorMessage: String?
    @Published var shortErrorMessage: String?
    @Published var isSaving = false

    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        formData = RemoteHistoryCreateRequest(patientID: patientID)
        do {
            types = try PatientRepository.fetchAnamnesisTypes(databaseFileURL: databaseFileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        super.init(trigger: .onChangeAndSubmit)
        bindModel { [unowned self] in self.formData }
    }

    func save() async -> Bool {
        isSaving = true
        do {
            let historyID = try PatientRepository.createRemoteHistory(formData, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.remoteHistoryCreated(historyID: historyID, patientID: patientID, databaseURL: databaseFileURL))
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}
