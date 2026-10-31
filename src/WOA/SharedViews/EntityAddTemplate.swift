import SwiftUI

struct EntityAddTemplate<ViewModel: EntityAddViewModel, AddContent: View>: View {
    @ObservedObject var viewModel: ViewModel
    let entityName: String
    let parentName: String
    let onCancel: () -> Void
    let onSuccess: () -> Void
    @Binding var saveResult: SaveResultState?
    @ViewBuilder let addContent: () -> AddContent

    var body: some View {
        let entityNameFLU = entityName.firstLetterUppercased
        Form {
            Section {
                addContent()
            } header: {
                Label("Aggiungi \(entityNameFLU)", systemImage: "doc.badge.plus")
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage).appErrorText()
                }
            }


            Section {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                        Label("Pronto a salvare?", systemImage: "doc.text.fill").font(.headline)
                        Text("Controlla i dettagli di \(entityName) prima di creare questo record.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    FormActionBar(
                        title: "Aggiungi \(entityNameFLU)",
                        systemImage: "doc.badge.plus",
                        submissionStyle: .add,
                        isLoading: viewModel.isSaving,
                        onCancel: onCancel,
                        onSubmit: {
                            let didSave = await viewModel.save()
                            saveResult = didSave
                                ? .success
                                : .failure(viewModel.shortErrorMessage ?? "Impossibile creare \(entityName). Riprova.")
                        }
                    )
                }
                .appSection()
            }
        }
        .appForm()
        .navigationTitle("Aggiungi \(entityNameFLU)")
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

#Preview {
    EntityAddTemplate(
        viewModel: ConsultoAddViewModel(
            patientID: 1,
            databaseFileURL: FileManager.default.temporaryDirectory.appendingPathComponent("woa-preview.db"),
            dataChangeCoordinator: DataChangeCoordinator()
        ),
        entityName: "consulto",
        parentName: "paziente",
        onCancel: {},
        onSuccess: {},
        saveResult: .constant(nil)
    ) {
        TextField("Descrizione", text: .constant("Visita di controllo"))
    }
}
