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
                                        ViewThatFits(in: .horizontal) {
                                            HStack(spacing: AppDesignSystem.spacingSM) { actionButtons }
                                            VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) { actionButtons }
                                        }
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
                VStack(spacing: AppDesignSystem.spacingSM) {
                    Image(systemName: "exclamationmark.circle")
                    Text(notFoundMessage)
                }
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
            Button("Elimina", role: .destructive) {
                Task { if await viewModel.delete() { onBack() } }
            }
        }
    }

    private var actionButtons: some View {
        Group {
            Button("Annulla") { isEditMode = false }
                .appSecondaryButton()
            Spacer()
            Button("Salva") {
                Task {
                    let didSave = await viewModel.save()
                    saveResult = didSave
                        ? .success
                    : .failure(viewModel.shortErrorMessage ?? "Impossibile salvare \(entityName.lowercased()). Riprova.")
                }
            }
            .appPrimaryButton()
            .disabled(viewModel.isSaving)
        }
    }
}
