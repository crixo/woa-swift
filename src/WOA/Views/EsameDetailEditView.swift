import SwiftUI

struct EsameDetailEditView: View {
    let onBackToConsulto: () -> Void
    @StateObject private var viewModel: EsameDetailEditViewModel
    @State private var isEditMode = false
    @State private var saveResult: SaveResultState?

    init(examID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onBackToConsulto: @escaping () -> Void) {
        self.onBackToConsulto = onBackToConsulto
        _viewModel = StateObject(wrappedValue: EsameDetailEditViewModel(examID: examID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        EntityDetailEditTemplate(
            viewModel: viewModel,
            entityName: "Exam",
            parentName: "Consultation",
            loadingMessage: "Loading exam...",
            notFoundMessage: "Exam not found",
            navigationTitle: "Exam",
            onBack: onBackToConsulto,
            isEditMode: $isEditMode,
            saveResult: $saveResult
        ) {
            FormField("Data", field: \ExamCreateRequest.date, form: viewModel, value: viewModel.formData.date) {
                DatePicker("Date", selection: $viewModel.formData.date, displayedComponents: .date)
            }
            
            FormField("Tipo", field: \ExamCreateRequest.typeID, form: viewModel, value: viewModel.formData.typeID) {
                Picker("Type", selection: $viewModel.formData.typeID) {
                    ForEach(viewModel.types) { type in
                        Text(type.name).tag(type.id)
                    }
                }
            }

            FormField("Description", field: \ExamCreateRequest.description, form: viewModel, isRequired: false) {
                TextField("Description", text: $viewModel.formData.description).textFieldStyle(.plain)
            }
        } displayContent: { exam in
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                EntityLabelForEdit(name:"Exam overview", id: exam.id)
                Text(exam.date?.formatted(date: .long, time: .omitted) ?? "No date").appOverviewDate()
                Text("Type: \(exam.typeName ?? "Not available")")
                Text(exam.description ?? "No description").appOverviewText()
            }
        }
    }
}
