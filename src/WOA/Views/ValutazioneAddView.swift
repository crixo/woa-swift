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
            entityName: "valutazione",
            parentName: "consulto",
            onCancel: onCancel,
            onSuccess: onSuccess,
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
        }
    }
}
