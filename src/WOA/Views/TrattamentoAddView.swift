import SwiftUI

// MARK: - Treatment Views

struct TrattamentoAddView: View {
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @StateObject private var viewModel: TrattamentoAddViewModel
    @State private var saveResult: SaveResultState?

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: TrattamentoAddViewModel(consultoID: consultoID, patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }
    
    var body: some View {
        EntityAddTemplate(
            viewModel: viewModel,
            entityName: "trattamento",
            parentName: "Consultation",
            onCancel: onCancel,
            onSuccess: onSuccess,
            saveResult: $saveResult
        ) {
            FormField("Date", field: \TreatmentCreateRequest.date, form: viewModel, value: viewModel.formData.date) {
                DatePicker("", selection: $viewModel.formData.date, displayedComponents: .date)
                    .labelsHidden()
            }
            
            FormField("Description", field: \TreatmentCreateRequest.description, form: viewModel, isRequired: true) {
                TextField("Add a description", text: $viewModel.formData.description).textFieldStyle(.plain)
            }
        }
    }
}
