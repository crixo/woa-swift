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
            loadingMessage: "Loading trattamento...",
            notFoundMessage: "trattamento not found",
            navigationTitle: "trattamento",
            onBack: onBackToConsulto,
            isEditMode: $isEditMode,
            saveResult: $saveResult
        ) {
            FormField("Date", field: \TreatmentCreateRequest.date, form: viewModel, value: viewModel.formData.date) {
                DatePicker("In che data e' avvenuto questo trattamento?", selection: $viewModel.formData.date, displayedComponents: .date)//.labelsHidden()
            }
            
            FormField("Description", field: \TreatmentCreateRequest.description, form: viewModel, isRequired: true) {
                TextField("Add a description", text: $viewModel.formData.description).textFieldStyle(.plain)
            }
        } displayContent: { treatment in
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                EntityLabelForEdit(name: "trattamento overview", id: treatment.id)
                Text(treatment.date?.formatted(date: .long, time: .omitted) ?? "No date").appOverviewDate()
                Text(treatment.description ?? "No description").appOverviewText()
            }
        }
    }
}
