
import SwiftUI

struct PazienteEditView: View {
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    let onCancel: () -> Void
    let onSuccess: () -> Void
    

    @StateObject private var viewModel: PazienteEditViewModel
    @State private var saveResult: SaveResultState?


    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void = {}, onSuccess: @escaping () -> Void = {}) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        _viewModel = StateObject(wrappedValue: PazienteEditViewModel(patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        EntityEditTemplate(
            viewModel: viewModel,
            entityName: "Paziente",
            parentName: "Paziente Details",
            onBack: onCancel,
            saveResult: $saveResult
        ) {
            FormField("Nome", field: \PatientCreateRequest.nome, form: viewModel, isRequired: true) {
                TextField("Nome", text: $viewModel.formData.nome).textFieldStyle(.plain)
            }
        
            FormField("Cognome", field: \PatientCreateRequest.cognome, form: viewModel, isRequired: true) {
                TextField("Cognome", text: $viewModel.formData.cognome).textFieldStyle(.plain)
            }
            
            FormField("Professione", field: \PatientCreateRequest.professione, form: viewModel, isRequired: false) {
                TextField("Professione", text: $viewModel.formData.professione.withDefault()).textFieldStyle(.plain)
            }
            
            FormField("Indirizzo", field: \PatientCreateRequest.indirizzo, form: viewModel, isRequired: false) {
                TextField("Indirizzo", text: $viewModel.formData.indirizzo.withDefault()).textFieldStyle(.plain)
            }
            
            FormField("Città", field: \PatientCreateRequest.citta, form: viewModel, isRequired: false) {
                TextField("Citta", text: $viewModel.formData.citta.withDefault()).textFieldStyle(.plain)
            }
            
            FormField("Telefono", field: \PatientCreateRequest.telefono, form: viewModel, isRequired: false) {
                TextField("Telefono", text: $viewModel.formData.telefono.withDefault()).textFieldStyle(.plain)
            }
            
            FormField("Cellulare", field: \PatientCreateRequest.cellulare, form: viewModel, isRequired: false) {
                TextField("Cellulare", text: $viewModel.formData.cellulare.withDefault()).textFieldStyle(.plain)
            }
            
            FormField("CAP", field: \PatientCreateRequest.cap, form: viewModel, isRequired: false) {
                TextField("CAP", text: $viewModel.formData.cap.withDefault()).textFieldStyle(.plain)
            }
            
            FormField("Email", field: \PatientCreateRequest.email, form: viewModel, isRequired: false) {
                TextField("Email", text: $viewModel.formData.email.withDefault()).textFieldStyle(.plain)
            }
            
            FormField("Province", field: \PatientCreateRequest.prov, form: viewModel, value: viewModel.formData.prov, isRequired: false) {
                Picker("Province", selection: $viewModel.formData.prov) {
                    Text("Select…").tag(String?.none)
                    ForEach(viewModel.allProvinces) { province in
                        Text(province.descrizione).tag(Optional(province.sigla))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            FormField("Data di nascita", field: \PatientCreateRequest.data_nascita, form: viewModel, value: viewModel.formData.data_nascita) {
//                DatePicker("", selection: $viewModel.formData.data_nascita.withDefault(), displayedComponents: .date)
//                    .labelsHidden()
                OptionalDatePicker(title: "Data di nascita", date: $viewModel.formData.data_nascita)
            }
        }
    }
}

#Preview {
    PazienteEditView(patientID: 1,databaseFileURL: URL(fileURLWithPath: "/tmp/test.db"), dataChangeCoordinator: DataChangeCoordinator())
}
