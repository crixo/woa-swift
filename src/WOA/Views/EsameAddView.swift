import SwiftUI

// MARK: - Exam Views

struct EsameAddView: View {
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @StateObject private var viewModel: EsameAddViewModel
    @State private var saveResult: SaveResultState?
    
    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: EsameAddViewModel(consultoID: consultoID, patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
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
            FormField("Data", field: \ExamCreateRequest.date, form: viewModel, value: viewModel.formData.date) {
                DatePicker("Date", selection: $viewModel.formData.date, displayedComponents: .date)
            }
            
            FormField("Tipo", field: \ExamCreateRequest.date, form: viewModel, value: viewModel.formData.typeID) {
                Picker("Type", selection: $viewModel.formData.typeID) {
                    ForEach(viewModel.types) { type in
                        Text(type.name).tag(type.id)
                    }
                }
            }

            FormField("Description", field: \ExamCreateRequest.description, form: viewModel, isRequired: false) {
                TextField("Description", text: $viewModel.formData.description).textFieldStyle(.plain)
            }
        }
    }
}
