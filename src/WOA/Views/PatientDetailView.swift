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

private enum ExamSaveResultState: Identifiable {
    case success
    case failure(String)

    var id: String {
        switch self {
        case .success:
            return "success"
        case .failure(let message):
            return "failure_\(message)"
        }
    }
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
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                        header(patient)

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .appErrorText()
                                .padding(.horizontal, AppDesignSystem.spacingSM)
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
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                Label("Patient overview", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(patient.fullName)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: AppDesignSystem.spacingSM) {
                    Text("ID \(patient.id)")
                    Text("•")
                    Text("Age \(patient.ageText)")
                    if patient.professione?.isEmpty == false {
                        Text("•")
                        Text(patient.professione ?? "Profession not available")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } actions: {
            HStack(spacing: AppDesignSystem.spacingSM) {
                if viewModel.isEditing {
                    Button("Cancel") { viewModel.cancelEditing() }
                        .appSecondaryButton()

                    Button("Save") { Task { await viewModel.save() } }
                        .appPrimaryButton()
                        .disabled(viewModel.isSaving)
                } else {
                    Button {
                        viewModel.beginEditing()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .appEditButton()

                    Button(role: .destructive) { viewModel.showDeleteConfirmation = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                        .appDeleteButton()
                        .disabled(viewModel.isDeleting)
                }
            }
        }
        .appCard(padding: AppDesignSystem.spacingLG)
    }

    @ViewBuilder
    private func attributesSection(_ patient: PatientDetail) -> some View {
        DisclosureGroup("Patient Attributes", isExpanded: $viewModel.isAttributesExpanded) {
            if viewModel.isEditing {
                patientForm
                    .padding(.top, AppDesignSystem.spacingSM)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(minimum: 180), alignment: .leading),
                    GridItem(.flexible(minimum: 180), alignment: .leading)
                ], alignment: .leading, spacing: AppDesignSystem.spacingSM) {
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
                .padding(.top, AppDesignSystem.spacingSM)
            }
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }

    private var patientForm: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
            formField("First name") {
                TextField("First name", text: $viewModel.editForm.nome)
                    .textFieldStyle(.plain)
            }

            formField("Last name") {
                TextField("Last name", text: $viewModel.editForm.cognome)
                    .textFieldStyle(.plain)
            }

            formField("Profession") {
                TextField("Profession", text: optionalBinding(\.professione))
                    .textFieldStyle(.plain)
            }

            formField("Address") {
                TextField("Address", text: optionalBinding(\.indirizzo))
                    .textFieldStyle(.plain)
            }

            formField("City") {
                TextField("City", text: optionalBinding(\.citta))
                    .textFieldStyle(.plain)
            }

            formField("Postal code") {
                TextField("Postal code", text: optionalBinding(\.cap))
                    .textFieldStyle(.plain)
            }

            formField("Phone") {
                TextField("Phone", text: optionalBinding(\.telefono))
                    .textFieldStyle(.plain)
            }

            formField("Mobile") {
                TextField("Mobile", text: optionalBinding(\.cellulare))
                    .textFieldStyle(.plain)
            }

            formField("Email") {
                TextField("Email", text: optionalBinding(\.email))
                    .textFieldStyle(.plain)
            }

            formField("Province") {
                Picker("Province", selection: $viewModel.editForm.prov) {
                    Text("Not selected").tag(String?.none)
                    ForEach(viewModel.provinces) { province in
                        Text(province.descrizione).tag(Optional(province.sigla))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            formField("Date of birth") {
                DatePicker("Date of birth", selection: Binding(
                    get: { viewModel.editForm.data_nascita ?? Date() },
                    set: { viewModel.editForm.data_nascita = $0 }
                ), displayedComponents: .date)
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = viewModel.validationErrors["nome"] { Text(error).appErrorText() }
            if let error = viewModel.validationErrors["cognome"] { Text(error).appErrorText() }
            if let error = viewModel.validationErrors["data_nascita"] { Text(error).appErrorText() }
        }
        .appSection()
    }

    private func formField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
                .padding(.horizontal, AppDesignSystem.spacingSM)
                .padding(.vertical, AppDesignSystem.spacingSM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private var consultationsSection: some View {
        DisclosureGroup("Appointments (\(viewModel.consultations.count))", isExpanded: $viewModel.isConsultationsExpanded) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                HStack {
                    Spacer()
                    Button(action: onAddConsultation) {
                        Label("Add Appointment", systemImage: "calendar.badge.plus")
                    }
                    .appAddButton()
                }

                if viewModel.consultations.isEmpty {
                    Text("No appointments recorded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.consultations) { item in
                        Button { onOpenConsultation(item.id) } label: {
                            summaryRow(item.date, item.initialProblem ?? "Reason not available")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, AppDesignSystem.spacingSM)
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }

    private var historySection: some View {
        DisclosureGroup("Remote Health History (\(viewModel.remoteHistory.count))", isExpanded: $viewModel.isHistoryExpanded) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                HStack {
                    Spacer()
                    Button(action: onAddHistory) {
                        Label("Add Health Issue", systemImage: "heart.text.square")
                    }
                    .appAddButton()
                }

                if viewModel.remoteHistory.isEmpty {
                    Text("No remote health history recorded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.remoteHistory) { item in
                        Button { onOpenHistory(item.id) } label: {
                            summaryRow(item.date, historySummary(item), lineLimit: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, AppDesignSystem.spacingSM)
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }

    private func historySummary(_ item: RemoteHistorySummary) -> String {
        let type = item.typeName?.isEmpty == false ? item.typeName! : "Type not available"
        let description = item.description?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let description, !description.isEmpty else {
            return type
        }

        return "\(type) • \(description)"
    }

    private func detailRow(_ label: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value?.isEmpty == false ? value! : "Not available")
                .font(.body)
        }
        .padding(.vertical, AppDesignSystem.spacingXS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.015), in: RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
        .padding(.bottom, 1)
    }

    private func summaryRow(_ date: Date?, _ text: String, lineLimit: Int = 2) -> some View {
        let dateText = date?.formatted(date: .abbreviated, time: .omitted) ?? "Date not available"
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppDesignSystem.spacingMD) {
                Text(dateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: LayoutMetrics.dateColumnMinWidth, alignment: .leading)

                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(lineLimit)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                Text(dateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(lineLimit)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, AppDesignSystem.spacingSM)
        .padding(.horizontal, AppDesignSystem.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
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
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                        header(consultation)
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .appErrorText()
                                .padding(.horizontal, AppDesignSystem.spacingSM)
                        }
                        if viewModel.isEditing {
                            consultationForm
                        } else {
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
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                Label("Appointment overview", systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(consultation.initialProblem ?? "No problem recorded")
                    .font(.title2)
                    .fontWeight(.bold)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppDesignSystem.spacingSM) {
                    Text(consultation.date?.formatted(date: .long, time: .omitted) ?? "No date")
                    Text("•")
                    Text("ID \(consultation.id)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } actions: {
            HStack(spacing: AppDesignSystem.spacingSM) {
                if viewModel.isEditing {
                    Button("Cancel") { viewModel.cancelEditing() }
                        .appSecondaryButton()

                    Button("Save") { Task { await viewModel.save() } }
                        .appPrimaryButton()
                        .disabled(viewModel.isSaving)
                } else {
                    Button {
                        viewModel.beginEditing()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .appEditButton()

                    Button(role: .destructive) {
                        viewModel.showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .appDeleteButton()
                    .disabled(viewModel.isDeleting)
                }
            }
        }
        .appCard(padding: AppDesignSystem.spacingLG)
    }

    private var consultationForm: some View {
        Form {
            Section("Appointment details") {
                DatePicker("Date", selection: $viewModel.editForm.date, displayedComponents: .date)
                TextField("Appointment reason", text: $viewModel.editForm.initialProblem, axis: .vertical)
            }
        }
        .appForm(maxWidth: LayoutMetrics.formMaxWidth)
        .appPanel(padding: AppDesignSystem.spacingLG)
    }

    @ViewBuilder
    private var treatmentsSection: some View {
        DisclosureGroup(isExpanded: $viewModel.isTreatmentsExpanded) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                if viewModel.treatments.isEmpty {
                    ContentUnavailableView("No treatments recorded", systemImage: "cross.case", description: Text("Add a treatment to keep the appointment record complete."))
                } else {
                    ForEach(viewModel.treatments) { treatment in
                        Button(action: { onOpenTreatment(treatment.id) }) {
                            HStack(spacing: AppDesignSystem.spacingMD) {
                                Image(systemName: "cross.case.fill")
                                    .foregroundStyle(.tint)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(treatment.date?.formatted(date: .abbreviated, time: .omitted) ?? "No date")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
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
                        .buttonStyle(.plain)
                        .appSection()
                    }
                }
                addRecordButton("Add Treatment", systemImage: "cross.case.fill", action: onAddTreatment)
            }
            .padding(.top, AppDesignSystem.spacingSM)
        } label: {
            sectionLabel("Treatments", count: viewModel.treatments.count, systemImage: "cross.case.fill")
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }

    @ViewBuilder
    private var evaluationsSection: some View {
        DisclosureGroup(isExpanded: $viewModel.isEvaluationsExpanded) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                if viewModel.evaluations.isEmpty {
                    ContentUnavailableView("No evaluations recorded", systemImage: "clipboard", description: Text("Add an evaluation to capture the clinical assessment."))
                } else {
                    ForEach(viewModel.evaluations) { evaluation in
                        Button(action: { onOpenEvaluation(evaluation.id) }) {
                            HStack(spacing: AppDesignSystem.spacingMD) {
                                Image(systemName: "clipboard.fill")
                                    .foregroundStyle(.tint)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(evaluation.structural ?? "No structural notes")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
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
                        .buttonStyle(.plain)
                        .appSection()
                    }
                }
                addRecordButton("Add Evaluation", systemImage: "clipboard.badge.plus", action: onAddEvaluation)
            }
            .padding(.top, AppDesignSystem.spacingSM)
        } label: {
            sectionLabel("Evaluations", count: viewModel.evaluations.count, systemImage: "clipboard.fill")
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }

    @ViewBuilder
    private var examsSection: some View {
        DisclosureGroup(isExpanded: $viewModel.isExamsExpanded) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                if viewModel.exams.isEmpty {
                    ContentUnavailableView("No exams recorded", systemImage: "doc.text.magnifyingglass", description: Text("Add an exam when new results are available."))
                } else {
                    ForEach(viewModel.exams) { exam in
                        Button(action: { onOpenExam(exam.id) }) {
                            HStack(spacing: AppDesignSystem.spacingMD) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundStyle(.tint)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(exam.date?.formatted(date: .abbreviated, time: .omitted) ?? "No date")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
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
                        .buttonStyle(.plain)
                        .appSection()
                    }
                }
                addRecordButton("Add Exam", systemImage: "doc.badge.plus", action: onAddExam)
            }
            .padding(.top, AppDesignSystem.spacingSM)
        } label: {
            sectionLabel("Exams", count: viewModel.exams.count, systemImage: "doc.text.magnifyingglass")
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }

    private func sectionLabel(_ title: String, count: Int, systemImage: String) -> some View {
        HStack(spacing: AppDesignSystem.spacingSM) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.07), in: Capsule())
        }
    }

    private func addRecordButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(action: action) {
                Label(title, systemImage: systemImage)
            }
            .appAddButton()
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
            Section("Appointment details") {
                DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
                TextField("Appointment reason", text: $viewModel.request.initialProblem)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .appErrorText()
                }
            }

            Section {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                        Label("Ready to save?", systemImage: "calendar.badge.plus")
                            .font(.headline)
                        Text("Review the appointment details before saving.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppDesignSystem.spacingSM) {
                            Button("Cancel", action: onCancel)
                                .appSecondaryButton()
                            Spacer()
                            Button { Task { if await viewModel.submit() { onSuccess() } } } label: {
                                Label("Add Appointment", systemImage: "calendar.badge.plus")
                            }
                                .appAddButton()
                                .disabled(viewModel.isSubmitting)
                        }

                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                            Button("Cancel", action: onCancel)
                                .appSecondaryButton()
                            Button { Task { if await viewModel.submit() { onSuccess() } } } label: {
                                Label("Add Appointment", systemImage: "calendar.badge.plus")
                            }
                                .appAddButton()
                                .disabled(viewModel.isSubmitting)
                        }
                    }
                }
                .appSection()
            }
        }
        .appForm()
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
            Section("History details") {
                DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
                Picker("Type", selection: $viewModel.request.typeID) {
                    ForEach(viewModel.types) { type in
                        Text(type.name).tag(type.id)
                    }
                }
                TextField("Description", text: $viewModel.request.description, axis: .vertical)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .appErrorText()
                }
            }

            Section {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                        Label("Ready to save?", systemImage: "heart.text.square")
                            .font(.headline)
                        Text("Review the health issue details before saving.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppDesignSystem.spacingSM) {
                            Button("Cancel", action: onCancel)
                                .appSecondaryButton()
                            Spacer()
                            Button { Task { if await viewModel.submit() { onSuccess() } } } label: {
                                Label("Add Health Issue", systemImage: "heart.text.square")
                            }
                                .appAddButton()
                                .disabled(viewModel.isSubmitting)
                        }

                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                            Button("Cancel", action: onCancel)
                                .appSecondaryButton()
                            Button { Task { if await viewModel.submit() { onSuccess() } } } label: {
                                Label("Add Health Issue", systemImage: "heart.text.square")
                            }
                                .appAddButton()
                                .disabled(viewModel.isSubmitting)
                        }
                    }
                }
                .appSection()
            }
        }
        .appForm()
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
            Section("Treatment details") {
                DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
                TextField("Description", text: $viewModel.request.description, axis: .vertical)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .appErrorText()
                }
            }

            Section {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                        Label("Ready to save?", systemImage: "cross.case.fill")
                            .font(.headline)
                        Text("Review the treatment details before creating this record.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppDesignSystem.spacingSM) {
                            Button("Cancel", action: onCancel)
                                .appSecondaryButton()
                            Spacer()
                            Button { Task { if await viewModel.submit() { onSuccess() } } } label: {
                                Label("Add Treatment", systemImage: "cross.case.fill")
                            }
                                .appAddButton()
                                .disabled(viewModel.isSubmitting)
                        }

                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                            Button("Cancel", action: onCancel)
                                .appSecondaryButton()
                            Button { Task { if await viewModel.submit() { onSuccess() } } } label: {
                                Label("Add Treatment", systemImage: "cross.case.fill")
                            }
                                .appAddButton()
                                .disabled(viewModel.isSubmitting)
                        }
                    }
                }
                .appSection()
            }
        }
        .appForm()
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
                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                            if isEditMode {
                                VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                                    HStack(alignment: .center, spacing: AppDesignSystem.spacingSM) {
                                        Label("Edit treatment", systemImage: "pencil.circle.fill")
                                            .font(.headline)
                                        Spacer()
                                        Button("Cancel") { isEditMode = false }
                                            .appSecondaryButton()
                                    }

                                    Form {
                                        Section("Treatment details") {
                                            DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
                                            TextField("Description", text: $viewModel.request.description, axis: .vertical)
                                        }

                                        if let errorMessage = viewModel.errorMessage {
                                            Section {
                                                Text(errorMessage)
                                                    .appErrorText()
                                            }
                                        }

                                        Section {
                                            VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                                                ViewThatFits(in: .horizontal) {
                                                    HStack(spacing: AppDesignSystem.spacingSM) {
                                                        Button("Cancel") { isEditMode = false }
                                                            .appSecondaryButton()
                                                        Spacer()
                                                        Button("Save") { Task { await viewModel.save() } }
                                                            .appPrimaryButton()
                                                            .disabled(viewModel.isSaving)
                                                    }

                                                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                                                        Button("Cancel") { isEditMode = false }
                                                            .appSecondaryButton()
                                                        Button("Save") { Task { await viewModel.save() } }
                                                            .appPrimaryButton()
                                                            .disabled(viewModel.isSaving)
                                                    }
                                                }
                                            }
                                            .appSection()
                                        }
                                    }
                                    .appForm(maxWidth: LayoutMetrics.formMaxWidth)
                                }
                                .appCard(padding: AppDesignSystem.spacingLG)
                            } else {
                                responsiveHeader {
                                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                                        Label("Treatment overview", systemImage: "cross.case.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        Text("ID \(treatment.id)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        Text(treatment.date?.formatted(date: .long, time: .omitted) ?? "No date")
                                            .font(.title3)
                                            .fontWeight(.semibold)

                                        Text(treatment.description ?? "No description")
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                } actions: {
                                    HStack(spacing: AppDesignSystem.spacingSM) {
                                        Button { isEditMode = true } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .appEditButton()

                                        Button(role: .destructive) { viewModel.showDeleteConfirmation = true } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .appDeleteButton()
                                        .disabled(viewModel.isDeleting)
                                    }
                                }
                                .appCard(padding: AppDesignSystem.spacingLG)
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
            Section("Evaluation details") {
                TextField("Structural", text: $viewModel.request.structural, axis: .vertical)
                TextField("Cranio-Sacral", text: $viewModel.request.cranioSacral, axis: .vertical)
                TextField("AK Orthodontic", text: $viewModel.request.akOrthodontic, axis: .vertical)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .appErrorText()
                }
            }

            Section {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                        Label("Ready to save?", systemImage: "clipboard.badge.checkmark")
                            .font(.headline)
                        Text("Review the evaluation details before saving.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppDesignSystem.spacingSM) {
                            Button("Cancel", action: onCancel)
                                .appSecondaryButton()
                            Spacer()
                            Button { Task { if await viewModel.submit() { onSuccess() } } } label: {
                                Label("Add Evaluation", systemImage: "clipboard.badge.plus")
                            }
                                .appAddButton()
                                .disabled(viewModel.isSubmitting)
                        }

                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                            Button("Cancel", action: onCancel)
                                .appSecondaryButton()
                            Button { Task { if await viewModel.submit() { onSuccess() } } } label: {
                                Label("Add Evaluation", systemImage: "clipboard.badge.plus")
                            }
                                .appAddButton()
                                .disabled(viewModel.isSubmitting)
                        }
                    }
                }
                .appSection()
            }
        }
        .appForm()
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
                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                            if isEditMode {
                                VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                                    HStack(alignment: .center, spacing: AppDesignSystem.spacingSM) {
                                        Label("Edit evaluation", systemImage: "clipboard.badge.checkmark")
                                            .font(.headline)
                                        Spacer()
                                        Button("Cancel") { isEditMode = false }
                                            .appSecondaryButton()
                                    }

                                    Form {
                                        Section("Evaluation details") {
                                            TextField("Structural", text: $viewModel.request.structural, axis: .vertical)
                                            TextField("Cranio-Sacral", text: $viewModel.request.cranioSacral, axis: .vertical)
                                            TextField("AK Orthodontic", text: $viewModel.request.akOrthodontic, axis: .vertical)
                                        }

                                        if let errorMessage = viewModel.errorMessage {
                                            Section {
                                                Text(errorMessage)
                                                    .appErrorText()
                                            }
                                        }

                                        Section {
                                            VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                                                ViewThatFits(in: .horizontal) {
                                                    HStack(spacing: AppDesignSystem.spacingSM) {
                                                        Button("Cancel") { isEditMode = false }
                                                            .appSecondaryButton()
                                                        Spacer()
                                                        Button("Save") { Task { await viewModel.save() } }
                                                            .appPrimaryButton()
                                                            .disabled(viewModel.isSaving)
                                                    }

                                                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                                                        Button("Cancel") { isEditMode = false }
                                                            .appSecondaryButton()
                                                        Button("Save") { Task { await viewModel.save() } }
                                                            .appPrimaryButton()
                                                            .disabled(viewModel.isSaving)
                                                    }
                                                }
                                            }
                                            .appSection()
                                        }
                                    }
                                    .appForm(maxWidth: LayoutMetrics.formMaxWidth)
                                }
                                .appCard(padding: AppDesignSystem.spacingLG)
                            } else {
                                responsiveHeader {
                                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                                        Label("Evaluation overview", systemImage: "clipboard.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        Text("ID \(evaluation.id)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                                            Text("Structural: \(evaluation.structural ?? "-")")
                                                .font(.body)
                                            Text("Cranio-Sacral: \(evaluation.cranioSacral ?? "-")")
                                                .font(.body)
                                            Text("AK Orthodontic: \(evaluation.akOrthodontic ?? "-")")
                                                .font(.body)
                                        }
                                    }
                                } actions: {
                                    HStack(spacing: AppDesignSystem.spacingSM) {
                                        Button { isEditMode = true } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .appEditButton()

                                        Button(role: .destructive) { viewModel.showDeleteConfirmation = true } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .appDeleteButton()
                                        .disabled(viewModel.isDeleting)
                                    }
                                }
                                .appCard(padding: AppDesignSystem.spacingLG)
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
            Section("Exam details") {
                DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
                Picker("Type", selection: $viewModel.request.typeID) {
                    ForEach(viewModel.types) { type in
                        Text(type.name).tag(type.id)
                    }
                }
                TextField("Description", text: $viewModel.request.description, axis: .vertical)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .appErrorText()
                }
            }

            Section {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                        Label("Ready to save?", systemImage: "doc.text.fill")
                            .font(.headline)
                        Text("Review the exam details before creating this record.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppDesignSystem.spacingSM) {
                            Button("Cancel", action: onCancel)
                                .appSecondaryButton()
                            Spacer()
                            Button { Task { if await viewModel.submit() { onSuccess() } } } label: {
                                Label("Add Exam", systemImage: "doc.badge.plus")
                            }
                                .appAddButton()
                                .disabled(viewModel.isSubmitting)
                        }

                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                            Button("Cancel", action: onCancel)
                                .appSecondaryButton()
                            Button { Task { if await viewModel.submit() { onSuccess() } } } label: {
                                Label("Add Exam", systemImage: "doc.badge.plus")
                            }
                                .appAddButton()
                                .disabled(viewModel.isSubmitting)
                        }
                    }
                }
                .appSection()
            }
        }
        .appForm()
        .navigationTitle("Add Exam")
    }
}

struct ExamDetailEditView: View {
    let onBackToConsulto: () -> Void
    @StateObject private var viewModel: ExamEditViewModel
    @State private var isEditMode = false
    @State private var saveResult: ExamSaveResultState?

    init(examID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onBackToConsulto: @escaping () -> Void) {
        self.onBackToConsulto = onBackToConsulto
        _viewModel = StateObject(wrappedValue: ExamEditViewModel(examID: examID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.exam == nil {
                ProgressView("Loading exam...")
            } else if let exam = viewModel.exam {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                        if isEditMode {
                            VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                                HStack(alignment: .center, spacing: AppDesignSystem.spacingSM) {
                                    Label("Edit exam", systemImage: "doc.text.fill")
                                        .font(.headline)
                                    Spacer()
                                    Button("Cancel") { isEditMode = false }
                                        .appSecondaryButton()
                                }

                                Form {
                                    Section("Exam details") {
                                        DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
                                        Picker("Type", selection: $viewModel.request.typeID) {
                                            ForEach(viewModel.types) { type in
                                                Text(type.name).tag(type.id)
                                            }
                                        }
                                        TextField("Description", text: $viewModel.request.description, axis: .vertical)
                                    }

                                    if let errorMessage = viewModel.errorMessage {
                                        Section {
                                            Text(errorMessage)
                                                .appErrorText()
                                        }
                                    }

                                    Section {
                                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                                            ViewThatFits(in: .horizontal) {
                                                HStack(spacing: AppDesignSystem.spacingSM) {
                                                    Button("Cancel") { isEditMode = false }
                                                        .appSecondaryButton()
                                                    Spacer()
                                                    Button("Save") {
                                                        Task {
                                                            let didSave = await viewModel.save()
                                                            saveResult = didSave ? .success : .failure(viewModel.shortErrorMessage ?? "Unable to save exam. Please try again.")
                                                        }
                                                    }
                                                    .appPrimaryButton()
                                                    .disabled(viewModel.isSaving)
                                                }

                                                VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                                                    Button("Cancel") { isEditMode = false }
                                                        .appSecondaryButton()
                                                    Button("Save") {
                                                        Task {
                                                            let didSave = await viewModel.save()
                                                            saveResult = didSave ? .success : .failure(viewModel.shortErrorMessage ?? "Unable to save exam. Please try again.")
                                                        }
                                                    }
                                                    .appPrimaryButton()
                                                    .disabled(viewModel.isSaving)
                                                }
                                            }
                                        }
                                        .appSection()
                                    }
                                }
                                .appForm(maxWidth: LayoutMetrics.formMaxWidth)
                            }
                            .appCard(padding: AppDesignSystem.spacingLG)
                        } else {
                            responsiveHeader {
                                VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                                    Label("Exam overview", systemImage: "doc.text.magnifyingglass")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)

                                    Text("ID \(exam.id)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text(exam.date?.formatted(date: .long, time: .omitted) ?? "No date")
                                        .font(.title3)
                                        .fontWeight(.semibold)

                                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                                        Text("Type: \(exam.typeName ?? "Not available")")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                        Text(exam.description ?? "No description")
                                            .font(.body)
                                    }
                                }
                            } actions: {
                                HStack(spacing: AppDesignSystem.spacingSM) {
                                    Button { isEditMode = true } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .appEditButton()

                                    Button(role: .destructive) { viewModel.showDeleteConfirmation = true } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .appDeleteButton()
                                    .disabled(viewModel.isDeleting)
                                }
                            }
                            .appCard(padding: AppDesignSystem.spacingLG)
                        }
                    }
                    .padding()
                    .frame(maxWidth: LayoutMetrics.formMaxWidth, alignment: .leading)
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
        .sheet(item: $saveResult) { result in
            ExamSaveResultModal(
                state: result,
                onDismiss: {
                    saveResult = nil
                    if case .success = result {
                        onBackToConsulto()
                    }
                }
            )
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

private struct ExamSaveResultModal: View {
    let state: ExamSaveResultState
    let onDismiss: () -> Void

    private var isSuccess: Bool {
        if case .success = state {
            return true
        }
        return false
    }

    private var title: String {
        isSuccess ? "Exam saved" : "Unable to save"
    }

    private var message: String {
        switch state {
        case .success:
            return "The exam was saved successfully."
        case .failure(let detail):
            return detail
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 36))
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)

            Button(isSuccess ? "Back to Consultation" : "Close") {
                onDismiss()
            }
            .appPrimaryButton()
            .frame(maxWidth: .infinity)
        }
        .padding(28)
        .frame(width: 420)
        .background(isSuccess ? Color.green.opacity(0.12) : Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: AppDesignSystem.cardRadius, style: .continuous))
    }
}
