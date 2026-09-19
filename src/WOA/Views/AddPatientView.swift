import SwiftUI

/// Layout constants for this view.
private enum LayoutMetrics {
    static let formMaxWidth: CGFloat = 560
}

/// View for adding a new patient to the database.
/// Includes form fields, real-time validation, date picker with manual input, and province dropdown.
struct AddPatientView: View {
    @StateObject private var viewModel: AddPatientViewModel
    let onCancel: () -> Void
    let onSuccess: () -> Void

    @State private var manualDateText: String = ""

    init(databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void = {}, onSuccess: @escaping () -> Void = {}) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: AddPatientViewModel(databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Form {
            // Required Section
            Section("Required Information") {
                // Nome
                TextField("First name *", text: $viewModel.formData.nome)
                    .onChange(of: viewModel.formData.nome) {
                        viewModel.validationErrors["nome"] = viewModel.validateField("nome") ?? ""
                    }
                if let error = viewModel.validationErrors["nome"], !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Cognome
                TextField("Last name *", text: $viewModel.formData.cognome)
                    .onChange(of: viewModel.formData.cognome) {
                        viewModel.validationErrors["cognome"] = viewModel.validateField("cognome") ?? ""
                    }
                if let error = viewModel.validationErrors["cognome"], !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
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
                .onChange(of: viewModel.selectedProvince) { _, newValue in
                    viewModel.formData.prov = newValue?.sigla ?? ""
                }

                if let error = viewModel.validationErrors["prov"], !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Date of Birth Section
            Section("Date of Birth") {
                DatePicker(
                    "Select Date",
                    selection: Binding(
                        get: { viewModel.formData.data_nascita ?? Date() },
                        set: { viewModel.formData.data_nascita = $0 }
                    ),
                    displayedComponents: .date
                )
                .onChange(of: viewModel.formData.data_nascita) {
                    updateManualDateText()
                }

                TextField("dd/MM/yyyy", text: $manualDateText)
                    .onAppear {
                        updateManualDateText()
                    }
                    .onChange(of: manualDateText) {
                        parseManualDate()
                    }

                if let error = viewModel.validationErrors["data_nascita"], !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let globalError = viewModel.globalErrorMessage, !globalError.isEmpty {
                Section {
                    Text(globalError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                        Label("Ready to save?", systemImage: "person.badge.plus")
                            .font(.headline)
                        Text("Review the required information before adding this patient to the database.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppDesignSystem.spacingSM) {
                            actionButtons
                        }

                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                            actionButtons
                        }
                    }
                }
                .appSection()
            }
        }
        .frame(maxWidth: LayoutMetrics.formMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.primary.opacity(0.025))
        .navigationTitle("Add New Patient")
        .alert("Success", isPresented: $viewModel.didSubmitSuccessfully) {
            Button("OK") {
                onSuccess()
            }
        } message: {
            Text("Patient added successfully.")
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
                await viewModel.submitForm()
            }
        } label: {
            Label(viewModel.isSubmitting ? "Adding..." : "Add Patient", systemImage: "person.badge.plus")
                .frame(maxWidth: .infinity)
        }
        .appAddButton()
        .disabled(viewModel.isSubmitting || viewModel.hasRealValidationErrors)
    }

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

// #Preview {
//     AddPatientView(databaseFileURL: URL(fileURLWithPath: "/tmp/test.db"))
// }
