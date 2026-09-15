import Foundation

@MainActor final class RemoteHistoryDetailViewModel: ObservableObject {
    let historyID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    
    @Published private(set) var history: RemoteHistoryDetail?
    @Published var request: RemoteHistoryCreateRequest
    @Published var types: [AnamnesisType] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published private(set) var saveSucceeded: Bool?

    init(historyID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.historyID = historyID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        request = RemoteHistoryCreateRequest(patientID: 0)
        do {
            types = try PatientRepository.fetchAnamnesisTypes(databaseFileURL: databaseFileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load() async {
        isLoading = true
        do {
            history = try PatientRepository.fetchRemoteHistoryItem(by: historyID, databaseFileURL: databaseFileURL)
            if let history {
                request = RemoteHistoryCreateRequest(
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

    func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try PatientRepository.updateRemoteHistory(request, id: historyID, databaseFileURL: databaseFileURL)
            if let history {
                dataChangeCoordinator.publishChange(.remoteHistoryUpdated(historyID: historyID, patientID: history.patientID, databaseURL: databaseFileURL))
            }
            saveSucceeded = true
            isSaving = false
        } catch {
            errorMessage = error.localizedDescription
            saveSucceeded = false
            isSaving = false
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
