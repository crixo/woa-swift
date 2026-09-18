import SwiftUI

/// Layout constants shared by the patient/consultation/treatment/evaluation/exam detail views in this file.
private enum LayoutMetrics {
    static let readableContentMaxWidth: CGFloat = 760
    static let formMaxWidth: CGFloat = 560
    static let dateColumnMinWidth: CGFloat = 100
}

/// Wide: info leading, actions trailing. Compact: info above, actions below.
@ViewBuilder
private func responsiveHeader<Info: View, Actions: View>(
    @ViewBuilder info: () -> Info,
    @ViewBuilder actions: () -> Actions
) -> some View {
    ViewThatFits(in: .horizontal) {
        HStack(alignment: .top) {
            info()
            Spacer()
            actions()
        }
        VStack(alignment: .leading, spacing: 8) {
            info()
            HStack {
                actions()
            }
        }
    }
}

/// Reusable save-result confirmation card used by the treatment/evaluation/exam edit views.
private func saveResultCard(succeeded: Bool, successMessage: String, failureMessage: String, backLabel: String, onBack: @escaping () -> Void) -> some View {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(succeeded ? .green : .red)
                .font(.title2)
            Text(succeeded ? successMessage : failureMessage)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(succeeded ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(8)

        Spacer()

        Button(action: onBack) {
            Text(backLabel)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding()
    }
    .padding()
}

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
                    .frame(maxWidth: LayoutMetrics.readableContentMaxWidth, alignment: .leading)
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
        responsiveHeader {
            VStack(alignment: .leading, spacing: 5) {
                Text(patient.fullName).font(.title).bold()
                Text("ID \(patient.id) • Age \(patient.ageText) • \(patient.professione ?? "Profession not available")")
                    .foregroundStyle(.secondary)
            }
        } actions: {
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
            Picker("Province", selection: $viewModel.editForm.prov) {
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
        let dateText = date?.formatted(date: .abbreviated, time: .omitted) ?? "Date not available"
        return ViewThatFits(in: .horizontal) {
            HStack {
                Text(dateText)
                    .frame(minWidth: LayoutMetrics.dateColumnMinWidth, alignment: .leading)
                Text(text).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(dateText).font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    Text(text).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 5)
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<PatientCreateRequest, String?>) -> Binding<String> {
        Binding(get: { viewModel.editForm[keyPath: keyPath] ?? "" }, set: { viewModel.editForm[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }
}

#Preview("Compact") {
    PatientDetailView(
        patientID: 1,
        databaseFileURL: URL(fileURLWithPath: "/tmp/preview.db"),
        dataChangeCoordinator: DataChangeCoordinator(),
        onOpenConsultation: { _ in }, onAddConsultation: {}, onOpenHistory: { _ in }, onAddHistory: {}, onDeleted: {}
    )
    .frame(width: 380, height: 600)
}

#Preview("Standard") {
    PatientDetailView(
        patientID: 1,
        databaseFileURL: URL(fileURLWithPath: "/tmp/preview.db"),
        dataChangeCoordinator: DataChangeCoordinator(),
        onOpenConsultation: { _ in }, onAddConsultation: {}, onOpenHistory: { _ in }, onAddHistory: {}, onDeleted: {}
    )
    .frame(width: 700, height: 700)
}

#Preview("Wide") {
    PatientDetailView(
        patientID: 1,
        databaseFileURL: URL(fileURLWithPath: "/tmp/preview.db"),
        dataChangeCoordinator: DataChangeCoordinator(),
        onOpenConsultation: { _ in }, onAddConsultation: {}, onOpenHistory: { _ in }, onAddHistory: {}, onDeleted: {}
    )
    .frame(width: 1100, height: 800)
}

struct ConsultoPatientDetailView: View {
    let onOpenTreatment: (Int) -> Void
    let onAddTreatment: () -> Void
    let onOpenEvaluation: (Int) -> Void
    let onAddEvaluation: () -> Void
    let onOpenExam: (Int) -> Void
    let onAddExam: () -> Void
    let onDeleted: () -> Void
    
    @StateObject private var viewModel: ConsultoDetailViewModel

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onOpenTreatment: @escaping (Int) -> Void, onAddTreatment: @escaping () -> Void, onOpenEvaluation: @escaping (Int) -> Void, onAddEvaluation: @escaping () -> Void, onOpenExam: @escaping (Int) -> Void, onAddExam: @escaping () -> Void, onDeleted: @escaping () -> Void) {
        self.onOpenTreatment = onOpenTreatment
        self.onAddTreatment = onAddTreatment
        self.onOpenEvaluation = onOpenEvaluation
        self.onAddEvaluation = onAddEvaluation
        self.onOpenExam = onOpenExam
        self.onAddExam = onAddExam
        self.onDeleted = onDeleted
        _viewModel = StateObject(wrappedValue: ConsultoDetailViewModel(consultoID: consultoID, patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.consultation == nil {
                ProgressView("Loading consultation...")
            } else if let consultation = viewModel.consultation {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(consultation)
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                        if !viewModel.isEditing {
                            treatmentsSection
                            evaluationsSection
                            examsSection
                        }
                    }
                    .padding()
                    .frame(maxWidth: LayoutMetrics.readableContentMaxWidth, alignment: .leading)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                    Text("Consultation not found")
                }
            }
        }
        .navigationTitle("Consultation Details")
        .onAppear {
            Task { await viewModel.load() }
        }
        .confirmationDialog("Delete this consultation?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Consultation", role: .destructive) {
                Task {
                    if await viewModel.delete() { onDeleted() }
                }
            }
        } message: {
            Text("This action removes the consultation record. Related records are not automatically deleted.")
        }
    }

    private func header(_ consultation: ConsultationDetail) -> some View {
        responsiveHeader {
            VStack(alignment: .leading, spacing: 5) {
                Text("ID \(consultation.id)").font(.headline).bold()
                Text(consultation.date?.formatted(date: .long, time: .omitted) ?? "No date").foregroundStyle(.secondary)
                Text(consultation.initialProblem ?? "No problem recorded").font(.subheadline)
            }
        } actions: {
            if viewModel.isEditing {
                Button("Cancel") { viewModel.cancelEditing() }
                Button("Save") { Task { await viewModel.save() } }
                    .disabled(viewModel.isSaving)
            } else {
                Button("✏️") { viewModel.beginEditing() }
                Button("🗑️", role: .destructive) { viewModel.showDeleteConfirmation = true }
                    .disabled(viewModel.isDeleting)
            }
        }
    }

    @ViewBuilder
    private var treatmentsSection: some View {
        DisclosureGroup("Treatments (\(viewModel.treatments.count))", isExpanded: $viewModel.isTreatmentsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.treatments.isEmpty {
                    Text("No treatments recorded").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.treatments) { treatment in
                        Button(action: { onOpenTreatment(treatment.id) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(treatment.date?.formatted(date: .abbreviated, time: .omitted) ?? "No date")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(treatment.description ?? "No description")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Button(action: onAddTreatment) {
                    Label("Add Treatment", systemImage: "plus.circle")
                }.buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var evaluationsSection: some View {
        DisclosureGroup("Evaluations (\(viewModel.evaluations.count))", isExpanded: $viewModel.isEvaluationsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.evaluations.isEmpty {
                    Text("No evaluations recorded").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.evaluations) { evaluation in
                        Button(action: { onOpenEvaluation(evaluation.id) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(evaluation.structural ?? "-").font(.caption).lineLimit(1)
                                    Text((evaluation.cranioSacral ?? "-") + " • " + (evaluation.akOrthodontic ?? "-"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Button(action: onAddEvaluation) {
                    Label("Add Evaluation", systemImage: "plus.circle")
                }.buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var examsSection: some View {
        DisclosureGroup("Exams (\(viewModel.exams.count))", isExpanded: $viewModel.isExamsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.exams.isEmpty {
                    Text("No exams recorded").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.exams) { exam in
                        Button(action: { onOpenExam(exam.id) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(exam.date?.formatted(date: .abbreviated, time: .omitted) ?? "No date")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text((exam.typeName ?? "No type") + " • " + (exam.description ?? "No description"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Button(action: onAddExam) {
                    Label("Add Exam", systemImage: "plus.circle")
                }.buttonStyle(.bordered)
            }
        }
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
        .frame(maxWidth: LayoutMetrics.formMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        .frame(maxWidth: LayoutMetrics.formMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Add Health Issue")
    }
}

// MARK: - Treatment Views

struct AddTreatmentView: View {
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @StateObject private var viewModel: TreatmentCreateViewModel

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: TreatmentCreateViewModel(consultoID: consultoID, patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Form {
            DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
            TextField("Description", text: $viewModel.request.description, axis: .vertical)
            if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Add Treatment") { Task { if await viewModel.submit() { onSuccess() } } }
                    .disabled(viewModel.isSubmitting)
            }
        }
        .padding()
        .frame(maxWidth: LayoutMetrics.formMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Add Treatment")
    }
}

struct TreatmentDetailEditView: View {
    let onBackToConsulto: () -> Void
    @StateObject private var viewModel: TreatmentEditViewModel
    @State private var isEditMode = false

    init(treatmentID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onBackToConsulto: @escaping () -> Void) {
        self.onBackToConsulto = onBackToConsulto
        _viewModel = StateObject(wrappedValue: TreatmentEditViewModel(treatmentID: treatmentID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.treatment == nil {
                ProgressView("Loading treatment...")
            } else if let treatment = viewModel.treatment {
                if let saveSucceeded = viewModel.saveSucceeded {
                    saveResultCard(
                        succeeded: saveSucceeded,
                        successMessage: "Treatment saved successfully",
                        failureMessage: "Failed to save treatment",
                        backLabel: "Back to Consultation",
                        onBack: onBackToConsulto
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if isEditMode {
                                Form {
                                    DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
                                    TextField("Description", text: $viewModel.request.description, axis: .vertical)
                                    if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundStyle(.red) }
                                    HStack {
                                        Button("Cancel") { isEditMode = false }
                                        Spacer()
                                        Button("Save") { Task { await viewModel.save() } }
                                            .disabled(viewModel.isSaving)
                                    }
                                }
                            } else {
                                responsiveHeader {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("ID \(treatment.id)").font(.headline).bold()
                                        Text(treatment.date?.formatted(date: .long, time: .omitted) ?? "No date").foregroundStyle(.secondary)
                                        Text(treatment.description ?? "No description")
                                    }
                                } actions: {
                                    Button("✏️") { isEditMode = true }
                                    Button("🗑️", role: .destructive) { viewModel.showDeleteConfirmation = true }
                                        .disabled(viewModel.isDeleting)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding()
                        .frame(maxWidth: LayoutMetrics.formMaxWidth, alignment: .leading)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                    Text("Treatment not found")
                }
            }
        }
        .navigationTitle("Treatment")
        .onAppear {
            Task { await viewModel.load() }
        }
        .confirmationDialog("Delete this treatment?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() { onBackToConsulto() }
                }
            }
        }
    }
}

// MARK: - Evaluation Views

struct AddEvaluationView: View {
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @StateObject private var viewModel: EvaluationCreateViewModel

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: EvaluationCreateViewModel(consultoID: consultoID, patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Form {
            TextField("Structural", text: $viewModel.request.structural, axis: .vertical)
            TextField("Cranio-Sacral", text: $viewModel.request.cranioSacral, axis: .vertical)
            TextField("AK Orthodontic", text: $viewModel.request.akOrthodontic, axis: .vertical)
            if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Add Evaluation") { Task { if await viewModel.submit() { onSuccess() } } }
                    .disabled(viewModel.isSubmitting)
            }
        }
        .padding()
        .frame(maxWidth: LayoutMetrics.formMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Add Evaluation")
    }
}

struct EvaluationDetailEditView: View {
    let onBackToConsulto: () -> Void
    @StateObject private var viewModel: EvaluationEditViewModel
    @State private var isEditMode = false

    init(evaluationID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onBackToConsulto: @escaping () -> Void) {
        self.onBackToConsulto = onBackToConsulto
        _viewModel = StateObject(wrappedValue: EvaluationEditViewModel(evaluationID: evaluationID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.evaluation == nil {
                ProgressView("Loading evaluation...")
            } else if let evaluation = viewModel.evaluation {
                if let saveSucceeded = viewModel.saveSucceeded {
                    saveResultCard(
                        succeeded: saveSucceeded,
                        successMessage: "Evaluation saved successfully",
                        failureMessage: "Failed to save evaluation",
                        backLabel: "Back to Consultation",
                        onBack: onBackToConsulto
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if isEditMode {
                                Form {
                                    TextField("Structural", text: $viewModel.request.structural, axis: .vertical)
                                    TextField("Cranio-Sacral", text: $viewModel.request.cranioSacral, axis: .vertical)
                                    TextField("AK Orthodontic", text: $viewModel.request.akOrthodontic, axis: .vertical)
                                    if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundStyle(.red) }
                                    HStack {
                                        Button("Cancel") { isEditMode = false }
                                        Spacer()
                                        Button("Save") { Task { await viewModel.save() } }
                                            .disabled(viewModel.isSaving)
                                    }
                                }
                            } else {
                                responsiveHeader {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("ID \(evaluation.id)").font(.headline).bold()
                                        Text("Structural: \(evaluation.structural ?? "-")").foregroundStyle(.secondary)
                                        Text("Cranio-Sacral: \(evaluation.cranioSacral ?? "-")").foregroundStyle(.secondary)
                                        Text("AK Orthodontic: \(evaluation.akOrthodontic ?? "-")").foregroundStyle(.secondary)
                                    }
                                } actions: {
                                    Button("✏️") { isEditMode = true }
                                    Button("🗑️", role: .destructive) { viewModel.showDeleteConfirmation = true }
                                        .disabled(viewModel.isDeleting)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding()
                        .frame(maxWidth: LayoutMetrics.formMaxWidth, alignment: .leading)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                    Text("Evaluation not found")
                }
            }
        }
        .navigationTitle("Evaluation")
        .onAppear {
            Task { await viewModel.load() }
        }
        .confirmationDialog("Delete this evaluation?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() { onBackToConsulto() }
                }
            }
        }
    }
}

// MARK: - Exam Views

struct AddExamView: View {
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @StateObject private var viewModel: ExamCreateViewModel

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onCancel: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.onCancel = onCancel
        self.onSuccess = onSuccess
        _viewModel = StateObject(wrappedValue: ExamCreateViewModel(consultoID: consultoID, patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
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
                Button("Add Exam") { Task { if await viewModel.submit() { onSuccess() } } }
                    .disabled(viewModel.isSubmitting)
            }
        }
        .padding()
        .frame(maxWidth: LayoutMetrics.formMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Add Exam")
    }
}

struct ExamDetailEditView: View {
    let onBackToConsulto: () -> Void
    @StateObject private var viewModel: ExamEditViewModel
    @State private var isEditMode = false

    init(examID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onBackToConsulto: @escaping () -> Void) {
        self.onBackToConsulto = onBackToConsulto
        _viewModel = StateObject(wrappedValue: ExamEditViewModel(examID: examID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.exam == nil {
                ProgressView("Loading exam...")
            } else if let exam = viewModel.exam {
                if let saveSucceeded = viewModel.saveSucceeded {
                    saveResultCard(
                        succeeded: saveSucceeded,
                        successMessage: "Exam saved successfully",
                        failureMessage: "Failed to save exam",
                        backLabel: "Back to Consultation",
                        onBack: onBackToConsulto
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if isEditMode {
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
                                        Button("Cancel") { isEditMode = false }
                                        Spacer()
                                        Button("Save") { Task { await viewModel.save() } }
                                            .disabled(viewModel.isSaving)
                                    }
                                }
                            } else {
                                responsiveHeader {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("ID \(exam.id)").font(.headline).bold()
                                        Text(exam.date?.formatted(date: .long, time: .omitted) ?? "No date").foregroundStyle(.secondary)
                                        Text("Type: \(exam.typeName ?? "Not available")").foregroundStyle(.secondary)
                                        Text(exam.description ?? "No description")
                                    }
                                } actions: {
                                    Button("✏️") { isEditMode = true }
                                    Button("🗑️", role: .destructive) { viewModel.showDeleteConfirmation = true }
                                        .disabled(viewModel.isDeleting)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding()
                        .frame(maxWidth: LayoutMetrics.formMaxWidth, alignment: .leading)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                    Text("Exam not found")
                }
            }
        }
        .navigationTitle("Exam")
        .onAppear {
            Task { await viewModel.load() }
        }
        .confirmationDialog("Delete this exam?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() { onBackToConsulto() }
                }
            }
        }
    }
}
