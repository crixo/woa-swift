import SwiftUI

struct EntityEditTemplate<ViewModel: EntityEditViewModel, EditContent: View>: View {
    typealias Entity = ViewModel.Entity
    
    @ObservedObject var viewModel: ViewModel
    let entityName: String
    let parentName: String
    let onBack: () -> Void
    @Binding var saveResult: SaveResultState?
    @ViewBuilder let editContent: () -> EditContent

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entity == nil {
                ProgressView("Caricamento \(entityName.capitalized)...")
            } else if viewModel.entity != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                            Label("Modifica \(entityName)", systemImage: "square.and.pencil")
                                .font(.headline)
                            Form {
                                editContent()
                                if let em = viewModel.errorMessage {
                                    Section {
                                        Text(em).appErrorText()
                                    }
                                }
                                Section {
                                    actionBar
                                        .appSection()
                                }
                            }
                            .appForm(maxWidth: LayoutMetrics.formMaxWidth)
                        }
                        .appCard(padding: AppDesignSystem.spacingLG)
                    }
                    .padding()
                    .frame(maxWidth: LayoutMetrics.formMaxWidth, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    "\(entityName.capitalized) non trovato",
                    systemImage: "exclamationmark.magnifyingglass"
                )
            }
        }
        .navigationTitle(entityName.capitalized)
        .task { await viewModel.load() }
        .sheet(item: $saveResult) { result in
            SaveResultModal(
                state: result,
                target: entityName,
                parent: parentName,
                onDismiss: {
                    saveResult = nil
                    if case .success = result { onBack() }
                }
            )
        }
    }

    private var actionBar: some View {
        FormActionBar(
            title: "Salva",
            systemImage: nil,
            submissionStyle: .save,
            isLoading: viewModel.isSaving,
            onCancel: onBack,
            onSubmit: {
                let didSave = await viewModel.save()
                saveResult = didSave
                    ? .success
                    : .failure(viewModel.shortErrorMessage ?? "Impossibile salvare \(entityName.lowercased()). Riprova.")
            }
        )
    }
}
