import SwiftUI

/// View for adding a new patient to the database.
/// Includes form fields, real-time validation, date picker with manual input, and province dropdown.
struct AddPatientView: View {
    @StateObject private var viewModel: AddPatientViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var manualDateText: String = ""
    
    init(databaseFileURL: URL) {
        _viewModel = StateObject(wrappedValue: AddPatientViewModel(databaseFileURL: databaseFileURL))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Required Section
                Section("Required Information") {
                    // Nome
                    TextField("First name *", text: $viewModel.formData.nome)
                        .onChange(of: viewModel.formData.nome) { _ in
                            viewModel.validationErrors["nome"] = viewModel.validateField("nome") ?? ""
                        }
                    if let error = viewModel.validationErrors["nome"], !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    // Cognome
                    TextField("Last name *", text: $viewModel.formData.cognome)
                        .onChange(of: viewModel.formData.cognome) { _ in
                            viewModel.validationErrors["cognome"] = viewModel.validateField("cognome") ?? ""
                        }
                    if let error = viewModel.validationErrors["cognome"], !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                // Optional Section
                Section("Optional Information") {
                    TextField("Profession", text: Binding(
                        get: { viewModel.formData.professione ?? "" },
                        set: { viewModel.formData.professione = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Address", text: Binding(
                        get: { viewModel.formData.indirizzo ?? "" },
                        set: { viewModel.formData.indirizzo = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("City", text: Binding(
                        get: { viewModel.formData.citta ?? "" },
                        set: { viewModel.formData.citta = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Phone", text: Binding(
                        get: { viewModel.formData.telefono ?? "" },
                        set: { viewModel.formData.telefono = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Mobile", text: Binding(
                        get: { viewModel.formData.cellulare ?? "" },
                        set: { viewModel.formData.cellulare = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Postal Code", text: Binding(
                        get: { viewModel.formData.cap ?? "" },
                        set: { viewModel.formData.cap = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Email", text: Binding(
                        get: { viewModel.formData.email ?? "" },
                        set: { viewModel.formData.email = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                // Province Section
                Section("Province") {
                    Picker("Province *", selection: $viewModel.selectedProvince) {
                        Text("Select Province").tag(LookupProvince?.none)
                        ForEach(viewModel.allProvinces) { province in
                            Text(province.descrizione).tag(LookupProvince?(province))
                        }
                    }
                    .onChange(of: viewModel.selectedProvince) { newValue in
                        viewModel.formData.prov = newValue?.sigla ?? ""
                    }
                    
                    if let error = viewModel.validationErrors["prov"], !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                // Date of Birth Section
                Section("Date of Birth") {
                    // DatePicker
                    DatePicker(
                        "Select Date",
                        selection: Binding(
                            get: { viewModel.formData.data_nascita ?? Date() },
                            set: { viewModel.formData.data_nascita = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .onChange(of: viewModel.formData.data_nascita) { _ in
                        updateManualDateText()
                    }
                    
                    // Manual text input for dd/MM/yyyy format
                    TextField("dd/MM/yyyy", text: $manualDateText)
                        .onAppear {
                            updateManualDateText()
                        }
                        .onChange(of: manualDateText) { _ in
                            parseManualDate()
                        }
                    
                    if let error = viewModel.validationErrors["data_nascita"], !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                // Global Error Message
                if let globalError = viewModel.globalErrorMessage, !globalError.isEmpty {
                    Section {
                        Text(globalError)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add New Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Patient") {
                        Task {
                            await viewModel.submitForm()
                        }
                    }
                    .disabled(viewModel.isSubmitting || !viewModel.validationErrors.isEmpty)
                }
            }
        }
        .alert("Success", isPresented: $viewModel.didSubmitSuccessfully) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Patient added successfully.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateManualDateText() {
        if let date = viewModel.formData.data_nascita {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            formatter.locale = Locale(identifier: "it_IT")
            manualDateText = formatter.string(from: date)
        } else {
            manualDateText = ""
        }
    }
    
    private func parseManualDate() {
        guard !manualDateText.isEmpty else {
            viewModel.formData.data_nascita = nil
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "it_IT")
        
        if let date = formatter.date(from: manualDateText) {
            viewModel.formData.data_nascita = date
            viewModel.validationErrors["data_nascita"] = viewModel.validateField("data_nascita") ?? ""
        } else {
            viewModel.validationErrors["data_nascita"] = "Invalid date format (use dd/MM/yyyy)"
        }
    }
}

#Preview {
    AddPatientView(databaseFileURL: URL(fileURLWithPath: "/tmp/test.db"))
}
