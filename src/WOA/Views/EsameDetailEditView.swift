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
            entityName: "esame",
            parentName: "consulto",
            loadingMessage: "Caricamento esame...",
            notFoundMessage: "Esame non trovato",
            navigationTitle: "Esame",
            onBack: onBackToConsulto,
            isEditMode: $isEditMode,
            saveResult: $saveResult
        ) {
            FormField("Data", field: \ExamCreateRequest.date, form: viewModel, value: viewModel.formData.date) {
                DatePicker("Data", selection: $viewModel.formData.date, displayedComponents: .date)
            }
            
            FormField("Tipo", field: \ExamCreateRequest.typeID, form: viewModel, value: viewModel.formData.typeID) {
                Picker("Tipo", selection: $viewModel.formData.typeID) {
                    ForEach(viewModel.types) { type in
                        Text(type.name).tag(type.id)
                    }
                }

            }

            FormField("Descrizione", field: \ExamCreateRequest.description, form: viewModel, isRequired: false) {
                TextField("Descrizione", text: $viewModel.formData.description).textFieldStyle(.plain)
            }
        } displayContent: { exam in
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                EntityLabelForEdit(name:"Panoramica esame", id: exam.id)
                Text(exam.date?.formatted(date: .long, time: .omitted) ?? "Nessuna data").appOverviewDate()
                Text("Tipo: \(exam.typeName ?? "Non disponibile")")
                Text(exam.description ?? "Nessuna descrizione").appOverviewText()
            }
        }
    }
}

#Preview {
    EsameDetailEditView(
        examID: 1,
        databaseFileURL: FileManager.default.temporaryDirectory.appendingPathComponent("woa-preview.db"),
        dataChangeCoordinator: DataChangeCoordinator(),
        onBackToConsulto: {}
    )
}
