import SwiftUI

// MARK: - Evaluation Views

struct ValutazioneAddView: View {
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @StateObject private var viewModel: ValutazioneAddViewModel
    @State private var saveResult: SaveResultState?

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: ValutazioneAddViewModel(consultoID: consultoID, patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }
    
    var body: some View {
        EntityAddTemplate(
            viewModel: viewModel,
            entityName: "exam",
            parentName: "Consultation",
            onCancel: onCancel,
            onSuccess: onSuccess,
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
        }
    }
}
