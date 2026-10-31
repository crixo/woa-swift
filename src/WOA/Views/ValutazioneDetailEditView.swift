//
//  EvaluationDetailEditView.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 20/09/2026.
//

import SwiftUI

struct ValutazioneDetailEditView: View {
    let onBackToConsulto: () -> Void
    @StateObject private var viewModel: ValutazioneDetailEditViewModel
    @State private var isEditMode = false
    @State private var saveResult: SaveResultState?

    init(evaluationID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onBackToConsulto: @escaping () -> Void) {
        self.onBackToConsulto = onBackToConsulto
        _viewModel = StateObject(wrappedValue: ValutazioneDetailEditViewModel(evaluationID: evaluationID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        EntityDetailEditTemplate(
            viewModel: viewModel,
            entityName: "valutazione",
            parentName: "consulto",
            loadingMessage: "Caricamento valutazione...",
            notFoundMessage: "Valutazione non trovata",
            navigationTitle: "Valutazione",
            onBack: onBackToConsulto,
            isEditMode: $isEditMode,
            saveResult: $saveResult
        ) {
            FormField("Strutturale", field: \EvaluationCreateRequest.structural, form: viewModel, isRequired: false) {
                TextField("Strutturale", text: $viewModel.formData.structural).textFieldStyle(.plain)
            }
            FormField("Cranio-sacrale", field: \EvaluationCreateRequest.cranioSacral, form: viewModel, isRequired: false) {
                TextField("Cranio-sacrale", text: $viewModel.formData.cranioSacral).textFieldStyle(.plain)
            }
            FormField("AK Ortodontico", field: \EvaluationCreateRequest.akOrthodontic, form: viewModel, isRequired: false) {
                TextField("AK Ortodontico", text: $viewModel.formData.akOrthodontic).textFieldStyle(.plain)
            }
        } displayContent: { evaluation in
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                EntityLabelForEdit(name: "Valutazione", id: evaluation.id)
                Text("Strutturale: \(evaluation.structural ?? "-")")
                Text("Cranio-sacrale: \(evaluation.cranioSacral ?? "-")")
                Text("AK Ortodontico: \(evaluation.akOrthodontic ?? "-")")
            }
        }
    }
}
