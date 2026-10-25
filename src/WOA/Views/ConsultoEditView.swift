import SwiftUI

struct ConsultoEditView: View {
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    let onCancel: () -> Void
    let onSuccess: () -> Void
    
    @StateObject private var viewModel: ConsultoEditViewModel
    @State private var saveResult: SaveResultState?

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void = {}, onSuccess: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: ConsultoEditViewModel(consultoID: consultoID, patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
    }

    var body: some View {
        EntityEditTemplate(
            viewModel: viewModel,
            entityName: "Consulto",
            parentName: "Consulto Details",
            onBack: onCancel,
            saveResult: $saveResult
        ) {
            FormField("Data", field: \ConsultoRequest.date, form: viewModel, value: viewModel.formData.date, isRequired: true) {
                DatePicker("In che data è avvenuto il consulto?", selection: $viewModel.formData.date, displayedComponents: .date)
                    .labelsHidden()
            }
            
            FormField("Problema iniziale", field: \.initialProblem, form: viewModel, isRequired: true) {
                TextField("Inserisci problema iniziale", text: $viewModel.formData.initialProblem).textFieldStyle(.plain)
            }
        }
    }

}
