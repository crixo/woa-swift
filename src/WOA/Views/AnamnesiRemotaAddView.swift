//
//  AddRemoteHistoryView.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 20/09/2026.
//

import SwiftUI

struct AnamnesiRemotaAddView: View {
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @StateObject private var viewModel: AnamnesiRemotaAddViewModel
    @State private var saveResult: SaveResultState?

    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: AnamnesiRemotaAddViewModel(patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }
    
    var body: some View {
        EntityAddTemplate(
            viewModel: viewModel,
            entityName: "anamnesi remota",
            parentName: "paziente",
            onCancel: onCancel,
            onSuccess: onSuccess,
            saveResult: $saveResult
        ) {
            FormField("Data", field: \RemoteHistoryCreateRequest.date, form: viewModel, value: viewModel.formData.date) {
                DatePicker("In che data e' avvenuta la visita?", selection: $viewModel.formData.date, displayedComponents: .date)
            }
            
            FormField("Tipo", field: \RemoteHistoryCreateRequest.date, form: viewModel, value: viewModel.formData.typeID) {
                Picker("Type", selection: $viewModel.formData.typeID) {
                    ForEach(viewModel.types) { type in
                        Text(type.name).tag(type.id)
                    }
                }
            }
            
            FormField("Descrizione", field: \RemoteHistoryCreateRequest.description, form: viewModel, isRequired: true) {
                TextField("Add a description", text: $viewModel.formData.description).textFieldStyle(.plain)
            }
        }
    }
}
