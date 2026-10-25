import SwiftUI

/// View for adding a new patient to the database.
/// Includes form fields, real-time validation, date picker with manual input, and province dropdown.
struct PazienteAddView: View {
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @StateObject private var viewModel: PazienteAddViewModel
    @State private var saveResult: SaveResultState?
    @State private var manualDateText: String = ""


    init(databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void = {}, onSuccess: @escaping () -> Void = {}) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: PazienteAddViewModel(databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        EntityAddTemplate(
            viewModel: viewModel,
            entityName: "paziente",
            parentName: "search",
            onCancel: onCancel,
            onSuccess: onSuccess,
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
                Picker("Province", selection: $viewModel.selectedProvince) {
                    Text("Select…").tag(LookupProvince?.none)
                    ForEach(viewModel.allProvinces) { province in
                        Text(province.descrizione).tag(LookupProvince?(province))
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

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            onCancel()
        } label: {
            Label("Cancel", systemImage: "xmark")
                .frame(maxWidth: .infinity)
        }
        .appSecondaryButton()

        Button {
            Task {
                let didSave = await viewModel.save()
                saveResult = didSave
                    ? .success
                    : .failure("Creazione nuovo paziente non riuscita. Please try again.")
            }
        } label: {
            Label(viewModel.isSaving ? "Adding..." : "Add Patient", systemImage: "person.badge.plus")
                .frame(maxWidth: .infinity)
        }
        .appAddButton()
        .disabled(viewModel.isSaving || viewModel.hasRealValidationErrors)
    }
}

 #Preview {
     PazienteAddView(databaseFileURL: URL(fileURLWithPath: "/tmp/test.db"), dataChangeCoordinator: DataChangeCoordinator())
 }
