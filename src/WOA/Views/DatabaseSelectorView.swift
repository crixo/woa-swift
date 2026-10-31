import SwiftUI

/// Sub-component allowing the user to browse for and import a SQLite database file.
struct DatabaseSelectorView: View {

    @ObservedObject var viewModel: DatabaseManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                Label("Database file", systemImage: "externaldrive.fill")
                    .font(.headline)

                if let selectedPath = viewModel.selectedPath {
                    Text(selectedPath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No file selected")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(
                "Copy selected database into Application Support",
                isOn: $viewModel.copySelectedDatabaseToApplicationSupport
            )
            .toggleStyle(.checkbox)
            .disabled(viewModel.isImporting)

            Text(
                viewModel.copySelectedDatabaseToApplicationSupport
                    ? "WOA will use an Application Support copy."
                    : "WOA will use the selected database file directly and ask permission for its containing folder."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppDesignSystem.spacingSM) {
                Button("Browse Database File") {
                    viewModel.selectDatabase()
                }
                .appSecondaryButton()
                .disabled(viewModel.isImporting)

                Button("Import Database") {
                    viewModel.importDatabase()
                }
                .appPrimaryButton()
                .disabled(viewModel.selectedPath == nil || viewModel.isImporting)
            }

            if viewModel.isImporting {
                ProgressView("Validating database...")
                    .padding(.top, 2)
            }

            if let validationError = viewModel.validationError {
                Text(validationError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if let connectionError = viewModel.connectionError,
               viewModel.validationError == nil {
                Text(connectionError)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }
}
