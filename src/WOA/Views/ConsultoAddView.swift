import SwiftUI

struct ConsultoAddView: View {
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @StateObject private var viewModel: ConsultoAddViewModel
    @State private var saveResult: SaveResultState?

    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: ConsultoAddViewModel(patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        EntityAddTemplate(
            viewModel: viewModel,
            entityName: "consulto",
            parentName: "paziente detail",
            onCancel: onCancel,
            onSuccess: onSuccess,
            saveResult: $saveResult
        ) {
            FormField("Data", field: \ConsultoRequest.date, form: viewModel, value: viewModel.formData.date) {
                DatePicker("Date", selection: $viewModel.formData.date, displayedComponents: .date)
            }
            

            FormField("Description", field: \ConsultoRequest.initialProblem, form: viewModel, isRequired: false) {
                TextField("Description", text: $viewModel.formData.initialProblem).textFieldStyle(.plain)
            }
        }
    }
}
