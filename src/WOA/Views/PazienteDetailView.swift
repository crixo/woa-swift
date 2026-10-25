import SwiftUI

struct PazienteDetailView: View {
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    let onOpenConsultation: (Int) -> Void
    let onAddConsultation: () -> Void
    let onOpenHistory: (Int) -> Void
    let onAddHistory: () -> Void
    let onDeleted: () -> Void
    var onEditPatient: () -> Void = {}
    
    @StateObject private var viewModel: PazienteDetailViewModel
    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onOpenConsultation: @escaping (Int) -> Void, onAddConsultation: @escaping () -> Void, onOpenHistory: @escaping (Int) -> Void, onAddHistory: @escaping () -> Void, onDeleted: @escaping () -> Void, onEditPatient: @escaping () -> Void) {
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        self.onOpenConsultation = onOpenConsultation
        self.onAddConsultation = onAddConsultation
        self.onOpenHistory = onOpenHistory
        self.onAddHistory = onAddHistory
        self.onDeleted = onDeleted
        self.onEditPatient = onEditPatient
        _viewModel = StateObject(wrappedValue: PazienteDetailViewModel(patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.patient == nil {
                ProgressView("Loading patient...")
            } else if let patient = viewModel.patient {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                        //header(patient)
                        PatientHeaderView(
                            patient: patient,
                            isDeleting: viewModel.isDeleting,
                            showDeleteConfirmation: $viewModel.showDeleteConfirmation,
                            onEditPatient: onEditPatient//viewModel.beginEditing
                        )
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .appErrorText()
                                .padding(.horizontal, AppDesignSystem.spacingSM)
                        }
                        
                        attributesSection(patient)
                        
                        ConsultiList(
                            isConsultationsExpanded: $viewModel.isConsultationsExpanded,
                            consultations: viewModel.consultations,
                            onAddConsultation: onAddConsultation,
                            onOpenConsultation: onOpenConsultation
                        )
                        
                        AnamnesiRemoteList(
                            isHistoryExpanded: $viewModel.isHistoryExpanded,
                            remoteHistory: viewModel.remoteHistory,
                            onAddHistory: onAddHistory,
                            onOpenHistory: onOpenHistory
                        )
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
        .navigationTitle("Scheda Paziente")
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
    
    @ViewBuilder
    private func attributesSection(_ patient: PatientDetail) -> some View {
        DisclosureGroup("Anagrafica Paziente", isExpanded: $viewModel.isAttributesExpanded) {
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
        .appPanel(padding: AppDesignSystem.spacingLG)
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
}
    
struct PatientHeaderView: View {
    let patient: PatientDetail
    let isDeleting: Bool
    @Binding var showDeleteConfirmation : Bool
    let onEditPatient: () -> Void
    
    var body: some View {
        ResponsiveHeader {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                Label("Paziente overview", systemImage: "person.fill")
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
                Button {
                    //onBeginEditing()
                    //TODO: open PazienteEditView
                    onEditPatient()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .appEditButton()
                
                Button(role: .destructive) { showDeleteConfirmation = true } label: {
                    Label("Delete", systemImage: "trash")
                }
                .appDeleteButton()
                .disabled(isDeleting)
                
            }
        }
        .appCard(padding: AppDesignSystem.spacingLG)
    }
    
//    func onAddPatient() {
//        let url = URL(fileURLWithPath: "")
//        navigationPath.append(.addPatient(databaseURL: url))
//    }
}


struct ConsultiList: View {
    @Binding var isConsultationsExpanded : Bool
    let consultations: [ConsultationSummary]
    let onAddConsultation: () -> Void
    let onOpenConsultation: (Int) -> Void
        
    var body: some View {
        DisclosureGroup("Consulti (\(consultations.count))", isExpanded: $isConsultationsExpanded) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                HStack {
                    Spacer()
                    Button(action: onAddConsultation) {
                        Label("Aggiungi Consulto", systemImage: "calendar.badge.plus")
                    }
                    .appAddButton()
                }
                
                if consultations.isEmpty {
                    Text("Nessun consulto registrato.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(consultations) { item in
                        Button { onOpenConsultation(item.id) } label: {
                            SummaryRow(date: item.date, text: item.initialProblem ?? "Reason not available")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, AppDesignSystem.spacingSM)
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }
    
}

struct AnamnesiRemoteList: View {
    @Binding var isHistoryExpanded : Bool
    let remoteHistory: [RemoteHistorySummary]
    let onAddHistory: () -> Void
    let onOpenHistory: (Int) -> Void
        
    var body: some View {
        DisclosureGroup("Anamnesi Remote (\(remoteHistory.count))", isExpanded: $isHistoryExpanded) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                HStack {
                    Spacer()
                    Button(action: onAddHistory) {
                        Label("Aggiungi Anamnesi Remota", systemImage: "heart.text.square")
                    }
                    .appAddButton()
                }
                
                if remoteHistory.isEmpty {
                    Text("Nessuna anamnesi remota registrata.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(remoteHistory) { item in
                        Button { onOpenHistory(item.id) } label: {
                            SummaryRow(date: item.date, text:historySummary(item), lineLimit: 1)
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
    
}
    

#Preview("Compact") {
    PazienteDetailView(
        patientID: 1,
        databaseFileURL: URL(fileURLWithPath: "/tmp/preview.db"),
        dataChangeCoordinator: DataChangeCoordinator(),
        onOpenConsultation: { _ in }, onAddConsultation: {}, onOpenHistory: { _ in }, onAddHistory: {}, onDeleted: {}, onEditPatient: {}
    )
    .frame(width: 380, height: 600)
}

#Preview("Standard") {
    PazienteDetailView(
        patientID: 1,
        databaseFileURL: URL(fileURLWithPath: "/tmp/preview.db"),
        dataChangeCoordinator: DataChangeCoordinator(),
        onOpenConsultation: { _ in }, onAddConsultation: {}, onOpenHistory: { _ in }, onAddHistory: {}, onDeleted: {}, onEditPatient: {}
    )
    .frame(width: 700, height: 700)
}

#Preview("Wide") {
    PazienteDetailView(
        patientID: 1,
        databaseFileURL: URL(fileURLWithPath: "/tmp/preview.db"),
        dataChangeCoordinator: DataChangeCoordinator(),
        onOpenConsultation: { _ in }, onAddConsultation: {}, onOpenHistory: { _ in }, onAddHistory: {}, onDeleted: {}, onEditPatient: {}
    )
    .frame(width: 1100, height: 800)
}



















