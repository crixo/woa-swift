import SwiftUI

/// Sub-component allowing the user to browse for and import a SQLite database file.
struct DatabaseSelectorView: View {

    @ObservedObject var viewModel: DatabaseSelectorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Browse Database File") {
                viewModel.selectDatabase()
            }
            .disabled(viewModel.isImporting)

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

            if viewModel.isImporting {
                ProgressView("Validating database...")
            }

            if let validationError = viewModel.validationError {
                Text(validationError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Button("Import Database") {
                viewModel.importDatabase()
            }
            .disabled(viewModel.selectedPath == nil || viewModel.isImporting)
        }
    }
}
