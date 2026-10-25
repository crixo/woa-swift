//
//  ConsultationCreateViewModel.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 26/09/2026.
//


import Foundation

@MainActor final class ConsultoAddViewModel: ModelFormValidator<ConsultoRequest>, EntityAddViewModel {
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    @Published var formData: ConsultoRequest
    @Published var errorMessage: String?
    @Published var shortErrorMessage: String?
    @Published var isSaving = false

    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        formData = ConsultoRequest(patientID: patientID)
        
        super.init(trigger: .onChangeAndSubmit)
        bindModel { [unowned self] in self.formData }
    }

    func save() async -> Bool {
        guard !formData.initialProblem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Appointment reason is required"
            return false
        }
        isSaving = true
        do {
            let consultationID = try PatientRepository.createConsultation(formData, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.consultationCreated(consultationID: consultationID, patientID: patientID, databaseURL: databaseFileURL))
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}
