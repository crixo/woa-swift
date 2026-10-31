import SwiftUI

struct EntityDetailEditTemplate<ViewModel: EntityDetailEditViewModel, EditContent: View, DisplayContent: View>: View {
    typealias Entity = ViewModel.Entity
    
    @ObservedObject var viewModel: ViewModel
    let entityName: String
    let parentName: String
    let loadingMessage: String
    let notFoundMessage: String
    let navigationTitle: String
    let onBack: () -> Void
    @Binding var isEditMode: Bool
    @Binding var saveResult: SaveResultState?
    @ViewBuilder let editContent: () -> EditContent
    @ViewBuilder let displayContent: (Entity) -> DisplayContent

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entity == nil {
                ProgressView(loadingMessage)
            } else if viewModel.entity != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                        if isEditMode {
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
                        } else {
                            ResponsiveHeader {
                                if let entity = viewModel.entity {
                                    displayContent(entity)
                                }
                            } actions: {
                                ResponsiveHeaderActions(
                                    isEditMode: $isEditMode,
                                    showDeleteConfirmation: $viewModel.showDeleteConfirmation,
                                    isDeleting: viewModel.isDeleting
                                )
                            }
                            .appCard(padding: AppDesignSystem.spacingLG)
                        }
                    }
                    .padding()
                    .frame(maxWidth: LayoutMetrics.formMaxWidth, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    notFoundMessage,
                    systemImage: "exclamationmark.magnifyingglass"
                )
            }
        }
        .navigationTitle(navigationTitle)
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
        .confirmationDialog("Eliminare questo \(entityName.lowercased())?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button("Elimina \(entityName.lowercased())", role: .destructive) {
                Task { if await viewModel.delete() { onBack() } }
            }
            Button("Annulla", role: .cancel) {}
        }
    }

    private var actionBar: some View {
        FormActionBar(
            title: "Salva",
            systemImage: nil,
            submissionStyle: .save,
            isLoading: viewModel.isSaving,
            onCancel: { isEditMode = false },
            onSubmit: {
                let didSave = await viewModel.save()
                saveResult = didSave
                    ? .success
                    : .failure(viewModel.shortErrorMessage ?? "Impossibile salvare \(entityName.lowercased()). Riprova.")
            }
        )
    }
}
