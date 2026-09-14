import SwiftUI

struct PatientDetailView: View {
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    let onOpenConsultation: (Int) -> Void
    let onAddConsultation: () -> Void
    let onOpenHistory: (Int) -> Void
    let onAddHistory: () -> Void
    let onDeleted: () -> Void

    @StateObject private var viewModel: PatientDetailViewModel

    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onOpenConsultation: @escaping (Int) -> Void, onAddConsultation: @escaping () -> Void, onOpenHistory: @escaping (Int) -> Void, onAddHistory: @escaping () -> Void, onDeleted: @escaping () -> Void) {
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        self.onOpenConsultation = onOpenConsultation
        self.onAddConsultation = onAddConsultation
        self.onOpenHistory = onOpenHistory
        self.onAddHistory = onAddHistory
        self.onDeleted = onDeleted
        _viewModel = StateObject(wrappedValue: PatientDetailViewModel(patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.patient == nil {
                ProgressView("Loading patient...")
            } else if let patient = viewModel.patient {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(patient)
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                        attributesSection(patient)
                        consultationsSection
                        historySection
                    }
                    .padding()
                    .frame(maxWidth: 760, alignment: .leading)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                    Text("Patient not found")
                }
            }
        }
        .navigationTitle("Patient Details")
        .onAppear {
            Task { await viewModel.load() }
        }
        .confirmationDialog("Delete this patient?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Patient", role: .destructive) {
                Task {
                    if await viewModel.delete() { onDeleted() }
                }
            }
        } message: {
            Text("This action removes the patient record. Related records are not automatically deleted.")
        }
    }

    private func header(_ patient: PatientDetail) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(patient.fullName).font(.title).bold()
                Text("ID \(patient.id) • Age \(patient.ageText) • \(patient.professione ?? "Profession not available")")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.isEditing {
                Button("Cancel") { viewModel.cancelEditing() }
                Button("Save") { Task { await viewModel.save() } }
                    .disabled(viewModel.isSaving)
            } else {
                Button("Edit") { viewModel.beginEditing() }
                Button("Delete", role: .destructive) { viewModel.showDeleteConfirmation = true }
                    .disabled(viewModel.isDeleting)
            }
        }
    }

    @ViewBuilder
    private func attributesSection(_ patient: PatientDetail) -> some View {
        DisclosureGroup("Patient Attributes", isExpanded: $viewModel.isAttributesExpanded) {
            if viewModel.isEditing {
                patientForm
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    detailRow("First name", patient.nome)
                    detailRow("Last name", patient.cognome)
                    detailRow("Profession", patient.professione)
                    detailRow("Address", patient.indirizzo)
                    detailRow("City", patient.citta)
                    detailRow("Province", patient.provincia ?? patient.prov)
                    detailRow("Postal code", patient.cap)
                    detailRow("Phone", patient.telefono)
                    detailRow("Mobile", patient.cellulare)
                    detailRow("Email", patient.email)
                    detailRow("Date of birth", patient.dataNascita?.formatted(date: .abbreviated, time: .omitted))
                }
                .padding(.top, 8)
            }
        }
    }

    private var patientForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("First name", text: $viewModel.editForm.nome)
            TextField("Last name", text: $viewModel.editForm.cognome)
            TextField("Profession", text: optionalBinding(\.professione))
            TextField("Address", text: optionalBinding(\.indirizzo))
            TextField("City", text: optionalBinding(\.citta))
            TextField("Postal code", text: optionalBinding(\.cap))
            TextField("Phone", text: optionalBinding(\.telefono))
            TextField("Mobile", text: optionalBinding(\.cellulare))
            TextField("Email", text: optionalBinding(\.email))
            Picker("Province", selection: optionalBinding(\.prov)) {
                Text("Not selected").tag(String?.none)
                ForEach(viewModel.provinces) { province in
                    Text(province.descrizione).tag(Optional(province.sigla))
                }
            }
            DatePicker("Date of birth", selection: Binding(get: { viewModel.editForm.data_nascita ?? Date() }, set: { viewModel.editForm.data_nascita = $0 }), displayedComponents: .date)
            if let error = viewModel.validationErrors["nome"] { Text(error).foregroundStyle(.red).font(.caption) }
            if let error = viewModel.validationErrors["cognome"] { Text(error).foregroundStyle(.red).font(.caption) }
            if let error = viewModel.validationErrors["data_nascita"] { Text(error).foregroundStyle(.red).font(.caption) }
        }
        .padding(.top, 8)
    }

    private var consultationsSection: some View {
        DisclosureGroup("Appointments (\(viewModel.consultations.count))", isExpanded: $viewModel.isConsultationsExpanded) {
            HStack {
                Spacer()
                Button("Add Appointment", action: onAddConsultation)
            }
            if viewModel.consultations.isEmpty {
                Text("No appointments recorded.").foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.consultations) { item in
                    Button { onOpenConsultation(item.id) } label: {
                        summaryRow(item.date, item.initialProblem ?? "Reason not available")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var historySection: some View {
        DisclosureGroup("Remote Health History (\(viewModel.remoteHistory.count))", isExpanded: $viewModel.isHistoryExpanded) {
            HStack {
                Spacer()
                Button("Add Health Issue", action: onAddHistory)
            }
            if viewModel.remoteHistory.isEmpty {
                Text("No remote health history recorded.").foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.remoteHistory) { item in
                    Button { onOpenHistory(item.id) } label: {
                        summaryRow(item.date, item.typeName ?? "Type not available")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String?) -> some View {
        LabeledContent(label, value: value?.isEmpty == false ? value! : "Not available")
    }

    private func summaryRow(_ date: Date?, _ text: String) -> some View {
        HStack {
            Text(date?.formatted(date: .abbreviated, time: .omitted) ?? "Date not available")
                .frame(width: 130, alignment: .leading)
            Text(text).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<PatientCreateRequest, String?>) -> Binding<String> {
        Binding(get: { viewModel.editForm[keyPath: keyPath] ?? "" }, set: { viewModel.editForm[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }
}

struct PatientAppointmentDetailView: View {
    @StateObject private var viewModel: ConsultationDetailViewModel

    init(consultationID: Int, databaseFileURL: URL) {
        _viewModel = StateObject(wrappedValue: ConsultationDetailViewModel(consultationID: consultationID, databaseFileURL: databaseFileURL))
    }

    var body: some View {
        Group {
            if let consultation = viewModel.consultation {
                Form {
                    LabeledContent("Appointment ID", value: String(consultation.id))
                    LabeledContent("Date", value: consultation.date?.formatted(date: .long, time: .omitted) ?? "Not available")
                    LabeledContent("Reason", value: consultation.initialProblem ?? "Not available")
                }
                .frame(maxWidth: 560)
            } else if viewModel.isLoading {
                ProgressView("Loading appointment...")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                    Text("Appointment not found")
                }
            }
        }
        .navigationTitle("Appointment")
        .task { await viewModel.load() }
    }
}

struct PatientHistoryDetailView: View {
    @StateObject private var viewModel: RemoteHistoryDetailViewModel

    init(historyID: Int, databaseFileURL: URL) {
        _viewModel = StateObject(wrappedValue: RemoteHistoryDetailViewModel(historyID: historyID, databaseFileURL: databaseFileURL))
    }

    var body: some View {
        Group {
            if let history = viewModel.history {
                Form {
                    LabeledContent("History ID", value: String(history.id))
                    LabeledContent("Date", value: history.date?.formatted(date: .long, time: .omitted) ?? "Not available")
                    LabeledContent("Type", value: history.typeName ?? "Not available")
                    LabeledContent("Description", value: history.description ?? "Not available")
                }
                .frame(maxWidth: 560)
            } else if viewModel.isLoading {
                ProgressView("Loading health history...")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.square")
                    Text("Health history not found")
                }
            }
        }
        .navigationTitle("Remote Health History")
        .task { await viewModel.load() }
    }
}

struct AddConsultationView: View {
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @StateObject private var viewModel: ConsultationCreateViewModel

    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: ConsultationCreateViewModel(patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Form {
            DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
            TextField("Appointment reason", text: $viewModel.request.initialProblem)
            if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Add Appointment") { Task { if await viewModel.submit() { onSuccess() } } }
                    .disabled(viewModel.isSubmitting)
            }
        }
        .padding()
        .frame(maxWidth: 560)
        .navigationTitle("Add Appointment")
    }
}

struct AddRemoteHistoryView: View {
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @StateObject private var viewModel: RemoteHistoryCreateViewModel

    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: RemoteHistoryCreateViewModel(patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Form {
            DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
            Picker("Type", selection: $viewModel.request.typeID) {
                ForEach(viewModel.types) { type in
                    Text(type.name).tag(type.id)
                }
            }
            TextField("Description", text: $viewModel.request.description, axis: .vertical)
            if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Add Health Issue") { Task { if await viewModel.submit() { onSuccess() } } }
                    .disabled(viewModel.isSubmitting)
            }
        }
        .padding()
        .frame(maxWidth: 560)
        .navigationTitle("Add Health Issue")
    }
}
