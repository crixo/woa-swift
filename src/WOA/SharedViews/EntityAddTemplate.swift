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
        Group {

                ScrollView {
                    //VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                            Label("Aggiungi \(entityName)", systemImage: "square.and.pencil")
                                .font(.headline)
                            Form {
                                addContent()
                                if let em = viewModel.errorMessage {
                                    Section {
                                        Text(em).appErrorText()
                                    }
                                }

                                Section {
                                    actionBar
                                        //.appSection()
                                }
                            }
                            .appForm(maxWidth: LayoutMetrics.formMaxWidth)
                        }
                        .appCard(padding: AppDesignSystem.spacingLG)
                    }
                    .padding()
                    .frame(maxWidth: LayoutMetrics.formMaxWidth, alignment: .leading)
                //}

        }
        .navigationTitle(entityName.capitalized)
        .sheet(item: $saveResult) { result in
            SaveResultModal(
                state: result,
                target: entityName,
                parent: parentName,
                onDismiss: {
                    saveResult = nil
                    if case .success = result { onCancel() }
                }
            )
        }
    }
    
    private var actionBar: some View {
        
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
                    title: "Aggiungi \(entityName.firstLetterUppercased)",
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
            //.appSection()
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
