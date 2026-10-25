//
//  TreatmentEditViewModel.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 26/09/2026.
//


import Foundation

@MainActor final class TrattamentoDetailEditViewModel: ModelFormValidator<TreatmentCreateRequest>, EntityDetailEditViewModel {
    let treatmentID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    
    var entity: TreatmentDetail? { treatment }//to comply the EntityDetailEditViewModel protocol
    @Published private(set) var treatment: TreatmentDetail?
    @Published var formData: TreatmentCreateRequest
    @Published var errorMessage: String?
    @Published var shortErrorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published private(set) var saveSucceeded: Bool?

    init(treatmentID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.treatmentID = treatmentID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        formData = TreatmentCreateRequest(consultoID: 0, patientID: 0)
        
        super.init(trigger: .onChangeAndSubmit)
        bindModel { [unowned self] in self.formData }
    }

    func load() async {
        isLoading = true
        do {
            treatment = try PatientRepository.fetchTreatment(by: treatmentID, databaseFileURL: databaseFileURL)
            if let treatment {
                formData = TreatmentCreateRequest(
                    consultoID: treatment.consultoID,
                    patientID: treatment.patientID,
                    date: treatment.date ?? Date(),
                    description: treatment.description ?? ""
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func save() async -> Bool {
        guard !formData.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Description is required"
            saveSucceeded = false
            return false
        }
        isSaving = true
        errorMessage = nil
        do {
            try PatientRepository.updateTreatment(formData, id: treatmentID, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.treatmentUpdated(treatmentID: treatmentID, consultoID: formData.consultoID, databaseURL: databaseFileURL))
            saveSucceeded = true
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            saveSucceeded = false
            isSaving = false
            return false
        }
    }

    func delete() async -> Bool {
        isDeleting = true
        errorMessage = nil
        do {
            try PatientRepository.deleteTreatment(id: treatmentID, databaseFileURL: databaseFileURL)
            if let treatment {
                dataChangeCoordinator.publishChange(.treatmentDeleted(treatmentID: treatmentID, consultoID: treatment.consultoID, databaseURL: databaseFileURL))
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
