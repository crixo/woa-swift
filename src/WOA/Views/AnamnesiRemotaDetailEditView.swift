import SwiftUI

private func infoPill(_ text: String) -> some View {
    Text(text)
        .font(.caption.weight(.semibold))
        .padding(.horizontal, AppDesignSystem.spacingSM)
        .padding(.vertical, AppDesignSystem.spacingXS)
        .foregroundStyle(.secondary)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
}

struct AnamnesiRemotaDetailEditView: View {
    let onBackToPatient: () -> Void
    @StateObject private var viewModel: AnamnesiRemotaDetailViewModel
    @State private var isEditMode = false
    @State private var saveResult: SaveResultState?

    init(historyID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onBackToPatient: @escaping () -> Void) {
        self.onBackToPatient = onBackToPatient
        _viewModel = StateObject(wrappedValue: AnamnesiRemotaDetailViewModel(historyID: historyID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }
    
    var body: some View {
        let entity = viewModel.history
        EntityDetailEditTemplate(
            viewModel: viewModel,
            entityName: "anamnesi remota",
            parentName: "paziente",
            loadingMessage: "Loading anamnesi remota...",
            notFoundMessage: "anamnesi remota non trovata",
            navigationTitle: "anamnesi remota",
            onBack: onBackToPatient,
            isEditMode: $isEditMode,
            saveResult: $saveResult
        ) {
            FormField("Data", field: \RemoteHistoryCreateRequest.date, form: viewModel, value: viewModel.formData.date) {
                DatePicker("Date", selection: $viewModel.formData.date, displayedComponents: .date)
            }
            
            FormField("Tipo", field: \RemoteHistoryCreateRequest.typeID, form: viewModel, value: viewModel.formData.typeID) {
                Picker("Type", selection: $viewModel.formData.typeID) {
                    ForEach(viewModel.types) { type in
                        Text(type.name).tag(type.id)
                    }
                }
            }

            FormField("Description", field: \RemoteHistoryCreateRequest.description, form: viewModel, isRequired: false) {
                TextField("Description", text: $viewModel.formData.description).textFieldStyle(.plain)
            }
        } displayContent: { exam in
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                Label("Health history overview", systemImage: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: AppDesignSystem.spacingSM) {
                    infoPill("Record #\(entity != nil ? String(entity!.id) : "N/A")")

                    if let typeName = entity?.typeName, !typeName.isEmpty {
                        infoPill(typeName)
                    }
                }

                Text(entity?.date?.formatted(date: .long, time: .omitted) ?? "No date").appOverviewDate()

                Text(entity?.description ?? "No description")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview("Compact") {
    AnamnesiRemotaDetailEditView(
        historyID: 1,
        databaseFileURL: URL(fileURLWithPath: "/tmp/preview.db"),
        dataChangeCoordinator: DataChangeCoordinator(),
        onBackToPatient: {}
    )
    .frame(width: 380, height: 500)
}

#Preview("Wide") {
    AnamnesiRemotaDetailEditView(
        historyID: 1,
        databaseFileURL: URL(fileURLWithPath: "/tmp/preview.db"),
        dataChangeCoordinator: DataChangeCoordinator(),
        onBackToPatient: {}
    )
    .frame(width: 1000, height: 600)
}
