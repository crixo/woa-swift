import SwiftUI

struct EntityAddTemplate<ViewModel: EntityAddViewModel, AddContent: View>: View {
    @ObservedObject var viewModel: ViewModel
    let entityName: String
    let parentName: String
//    let loadingMessage: String
//    let navigationTitle: String
//    let isSaving: Bool//
//    let errorMessage: String?
//    let shortErrorMessage: String?
//    let save: () async -> Bool//
    let onCancel: () -> Void//
    let onSuccess: () -> Void//
    @Binding var saveResult: SaveResultState?//
    @ViewBuilder let addContent: () -> AddContent//
    

    
    var body: some View {
        let entityNameFLU = entityName.firstLetterUppercased
        Form {
            Section{
                addContent()
            } header: {
                Label("Add \(entityNameFLU)", systemImage: "doc.badge.plus")
            }
            
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage).appErrorText()
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                        Label("Ready to save?", systemImage: "doc.text.fill").font(.headline)
                        Text("Review the \(entityName) details before creating this record.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    HStack(spacing: AppDesignSystem.spacingSM) {
                        Button("Cancel", action: onCancel).appSecondaryButton()
                        Spacer()
                        Button {
                            Task {
                                let didSave = await viewModel.save()
                                saveResult = didSave
                                    ? .success
                                : .failure(viewModel.shortErrorMessage ?? "Unable to create \(entityName). Please try again.")
                            }
                        } label: {
                            Label("Add \(entityNameFLU)", systemImage: "doc.badge.plus")
                        }
                        .appAddButton()
                        .disabled(viewModel.isSaving)
                    }
                }
                .appSection()
            }
        }
        .appForm()
        .navigationTitle("Add \(entityNameFLU)")
        .sheet(item: $saveResult) { result in
            SaveResultModal(
                state: result,
                target: entityNameFLU,
                parent: parentName,
                onDismiss: {
                    saveResult = nil
                    if case .success = result {
                        onSuccess()
                    }
                }
            )
        }
    }
}
