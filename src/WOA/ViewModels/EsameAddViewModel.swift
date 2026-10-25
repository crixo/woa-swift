//
//  ExamCreateViewModel.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 26/09/2026.
//


import Foundation

@MainActor final class EsameAddViewModel: ModelFormValidator<ExamCreateRequest>, EntityAddViewModel {
    let consultoID: Int
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    @Published var formData: ExamCreateRequest
    @Published var types: [ExamType] = []
    @Published var errorMessage: String?
    @Published var shortErrorMessage: String?
    @Published var isSaving = false

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.consultoID = consultoID
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        formData = ExamCreateRequest(consultoID: consultoID, patientID: patientID)
        do {
            types = try PatientRepository.fetchExamTypes(databaseFileURL: databaseFileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        super.init(trigger: .onChangeAndSubmit)
        bindModel { [unowned self] in self.formData }
    }

    func save() async -> Bool {
        isSaving = true
        do {
            let examID = try PatientRepository.createExam(formData, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.examCreated(examID: examID, consultoID: consultoID, databaseURL: databaseFileURL))
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}
