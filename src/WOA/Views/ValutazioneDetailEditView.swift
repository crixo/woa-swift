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
            entityName: "Evaluation",
            parentName: "Consultation",
            loadingMessage: "Loading evaluation...",
            notFoundMessage: "Evaluation not found",
            navigationTitle: "Evaluation",
            onBack: onBackToConsulto,
            isEditMode: $isEditMode,
            saveResult: $saveResult
        ) {
            FormField("Structural", field: \EvaluationCreateRequest.structural, form: viewModel, isRequired: false) {
                TextField("Strutturale", text: $viewModel.formData.structural).textFieldStyle(.plain)
            }
            FormField("Cranio-Sacrale", field: \EvaluationCreateRequest.cranioSacral, form: viewModel, isRequired: false) {
                TextField("Cranio-Sacrale", text: $viewModel.formData.cranioSacral).textFieldStyle(.plain)
            }
            FormField("AK Orthodontic", field: \EvaluationCreateRequest.akOrthodontic, form: viewModel, isRequired: false) {
                TextField("AK Orthodontic", text: $viewModel.formData.akOrthodontic).textFieldStyle(.plain)
            }
        } displayContent: { evaluation in
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                EntityLabelForEdit(name: "Evaluation", id: evaluation.id)
                Text("Structural: \(evaluation.structural ?? "-")")
                Text("Cranio-Sacral: \(evaluation.cranioSacral ?? "-")")
                Text("AK Orthodontic: \(evaluation.akOrthodontic ?? "-")")
            }
        }
    }
}
