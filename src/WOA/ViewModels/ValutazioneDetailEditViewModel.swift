//
//  EvaluationEditViewModel.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 26/09/2026.
//


import Foundation

@MainActor final class ValutazioneDetailEditViewModel: ModelFormValidator<EvaluationCreateRequest>, EntityDetailEditViewModel {
    let evaluationID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    
    var entity: EvaluationDetail? { evaluation }//to comply the EntityDetailEditViewModel protocol
    @Published private(set) var evaluation: EvaluationDetail?
    @Published var formData: EvaluationCreateRequest
    @Published var errorMessage: String?
    @Published var shortErrorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published private(set) var saveSucceeded: Bool?

    init(evaluationID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.evaluationID = evaluationID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        formData = EvaluationCreateRequest(consultoID: 0, patientID: 0)
        
        super.init(trigger: .onChangeAndSubmit)
        bindModel { [unowned self] in self.formData }
    }

    func load() async {
        isLoading = true
        do {
            evaluation = try PatientRepository.fetchEvaluation(by: evaluationID, databaseFileURL: databaseFileURL)
            if let evaluation {
                formData = EvaluationCreateRequest(
                    consultoID: evaluation.consultoID,
                    patientID: evaluation.patientID,
                    structural: evaluation.structural ?? "",
                    cranioSacral: evaluation.cranioSacral ?? "",
                    akOrthodontic: evaluation.akOrthodontic ?? ""
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
            try PatientRepository.updateEvaluation(formData, id: evaluationID, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.evaluationUpdated(evaluationID: evaluationID, consultoID: formData.consultoID, databaseURL: databaseFileURL))
            saveSucceeded = true
            shortErrorMessage = nil
            isSaving = false
            return true
        } catch {
            let detailedMessage = error.localizedDescription
            let shortMessage = "The exam could not be saved. Please review the details and try again."
            AppLogger.error("Failed to save exam \(evaluationID): \(detailedMessage)")
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
            try PatientRepository.deleteEvaluation(id: evaluationID, databaseFileURL: databaseFileURL)
            if let evaluation {
                dataChangeCoordinator.publishChange(.evaluationDeleted(evaluationID: evaluationID, consultoID: evaluation.consultoID, databaseURL: databaseFileURL))
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
