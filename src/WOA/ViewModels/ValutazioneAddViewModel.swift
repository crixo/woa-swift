//
//  EvaluationCreateViewModel.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 26/09/2026.
//


import Foundation

@MainActor final class ValutazioneAddViewModel: ModelFormValidator<EvaluationCreateRequest>, EntityAddViewModel {
    let consultoID: Int
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    @Published var formData: EvaluationCreateRequest
    @Published var errorMessage: String?
    @Published var shortErrorMessage: String?
    @Published var isSaving = false

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.consultoID = consultoID
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        formData = EvaluationCreateRequest(consultoID: consultoID, patientID: patientID)
        
        super.init(trigger: .onChangeAndSubmit)
        
        bindModel { [unowned self] in self.formData }
    }

    func save() async -> Bool {
        isSaving = true
        do {
            let evaluationID = try PatientRepository.createEvaluation(formData, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.evaluationCreated(evaluationID: evaluationID, consultoID: consultoID, databaseURL: databaseFileURL))
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}
