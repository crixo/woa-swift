import SwiftUI

/// Sub-component allowing the user to browse for and import a SQLite database file.
struct DatabaseSelectorView: View {

    @ObservedObject var viewModel: DatabaseManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                Label("File database", systemImage: "externaldrive.fill")
                    .font(.headline)

                if let selectedPath = viewModel.selectedPath {
                    Text(selectedPath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Nessun file selezionato")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(
                "Copia il database selezionato in Application Support",
                isOn: $viewModel.copySelectedDatabaseToApplicationSupport
            )
            .toggleStyle(.checkbox)
            .disabled(viewModel.isImporting)

            Text(
                viewModel.copySelectedDatabaseToApplicationSupport
                    ? "WOA userà una copia in Application Support."
                    : "WOA userà direttamente il file database selezionato e chiederà il permesso per la cartella contenente."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppDesignSystem.spacingSM) {
                Button("Sfoglia file database") {
                    viewModel.selectDatabase()
                }
                .appSecondaryButton()
                .disabled(viewModel.isImporting)

                Button("Importa database") {
                    viewModel.importDatabase()
                }
                .appPrimaryButton()
                .disabled(viewModel.selectedPath == nil || viewModel.isImporting)
            }

            if viewModel.isImporting {
                ProgressView("Validazione database...")
                    .padding(.top, 2)
            }

            if let validationError = viewModel.validationError {
                Text(validationError)
                    .appErrorText()
            }

            if let connectionError = viewModel.connectionError,
               viewModel.validationError == nil {
                Text(connectionError)
                    .appErrorText()
                    .textSelection(.enabled)
            }
        }
    }
}
