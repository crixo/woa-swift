import SwiftUI

struct TrattamentoDetailEditView: View {
    let onBackToConsulto: () -> Void
    @StateObject private var viewModel: TrattamentoDetailEditViewModel
    @State private var isEditMode = false
    @State private var saveResult: SaveResultState?

    init(treatmentID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onBackToConsulto: @escaping () -> Void) {
        self.onBackToConsulto = onBackToConsulto
        _viewModel = StateObject(wrappedValue: TrattamentoDetailEditViewModel(treatmentID: treatmentID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        EntityDetailEditTemplate(
            viewModel: viewModel,
            entityName: "trattamento",
            parentName: "consulto",
            loadingMessage: "Caricamento trattamento...",
            notFoundMessage: "trattamento non trovato",
            navigationTitle: "trattamento",
            onBack: onBackToConsulto,
            isEditMode: $isEditMode,
            saveResult: $saveResult
        ) {
            FormField("Data", field: \TreatmentCreateRequest.date, form: viewModel, value: viewModel.formData.date) {
                DatePicker("Data", selection: $viewModel.formData.date, displayedComponents: .date)
            }
            
            FormField("Descrizione", field: \TreatmentCreateRequest.description, form: viewModel, isRequired: true) {
                TextField("Aggiungi una descrizione", text: $viewModel.formData.description).textFieldStyle(.plain)
            }
        } displayContent: { treatment in
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                EntityLabelForEdit(name: "panoramica trattamento", id: treatment.id)
                Text(treatment.date?.formatted(date: .long, time: .omitted) ?? "Nessuna data").appOverviewDate()
                Text(treatment.description ?? "Nessuna descrizione").appOverviewText()
            }
        }
    }
}
