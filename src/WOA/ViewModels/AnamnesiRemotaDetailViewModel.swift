import Foundation

@MainActor final class AnamnesiRemotaDetailViewModel: ModelFormValidator<RemoteHistoryCreateRequest>, EntityDetailEditViewModel {
    let historyID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    
    var entity: RemoteHistoryDetail? { history }//to comply the EntityDetailEditViewModel protocol
    @Published private(set) var history: RemoteHistoryDetail?
    @Published var formData: RemoteHistoryCreateRequest
    @Published var types: [AnamnesisType] = []
    @Published var errorMessage: String?
    @Published var shortErrorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published private(set) var saveSucceeded: Bool?

    init(historyID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.historyID = historyID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        formData = RemoteHistoryCreateRequest(patientID: 0)
        do {
            types = try PatientRepository.fetchAnamnesisTypes(databaseFileURL: databaseFileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        super.init(trigger: .onChangeAndSubmit)
        bindModel { [unowned self] in self.formData }
    }

    func load() async {
        isLoading = true
        do {
            history = try PatientRepository.fetchRemoteHistoryItem(by: historyID, databaseFileURL: databaseFileURL)
            if let history {
                formData = RemoteHistoryCreateRequest(
                    patientID: history.patientID,
                    date: history.date ?? Date(),
                    typeID: history.typeID,
                    description: history.description ?? ""
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func save() async -> Bool  {
        isSaving = true
        errorMessage = nil
        do {
            try PatientRepository.updateRemoteHistory(formData, id: historyID, databaseFileURL: databaseFileURL)
            if let history {
                dataChangeCoordinator.publishChange(.remoteHistoryUpdated(historyID: historyID, patientID: history.patientID, databaseURL: databaseFileURL))
            }
            saveSucceeded = true
            shortErrorMessage = nil
            isSaving = false
            return true
        } catch {
            let detailedMessage = error.localizedDescription
            let shortMessage = "The anamnesi remota could not be saved. Please review the details and try again."
            AppLogger.error("Failed to save anamnesi remota \(historyID): \(detailedMessage)")
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
            try PatientRepository.deleteRemoteHistory(id: historyID, databaseFileURL: databaseFileURL)
            if let history {
                dataChangeCoordinator.publishChange(.remoteHistoryDeleted(historyID: historyID, patientID: history.patientID, databaseURL: databaseFileURL))
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
