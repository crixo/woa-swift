import SwiftUI

struct MigrationHistoryView: View {

    @StateObject private var viewModel: MigrationHistoryViewModel

    init(databaseURL: URL, migrationService: DatabaseMigrationService) {
        _viewModel = StateObject(
            wrappedValue: MigrationHistoryViewModel(
                databaseURL: databaseURL,
                migrationService: migrationService
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics2.contentSpacing) {
            
            HStack {
                Text("Cronologia migrazioni")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("Aggiorna", systemImage: "arrow.clockwise")
                }
                .appSecondaryButton()
                .disabled(viewModel.isLoading)
            }
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                if viewModel.isLoading {
                    ProgressView("Caricamento cronologia migrazioni...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Impossibile caricare la cronologia migrazioni",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.migrations.isEmpty {
                    ContentUnavailableView(
                        "Nessuna migrazione applicata",
                        systemImage: "externaldrive",
                        description: Text("Le migrazioni del database applicate appariranno qui.")
                    )
                } else {
                    List(viewModel.migrations) { migration in
                        migrationRow(migration)
                    }
                    .listStyle(.inset)
                }
            }
            .appPanel(padding: AppDesignSystem.spacingLG)
        }
        //.padding()
        .frame(maxWidth: LayoutMetrics2.contentMaxWidth, alignment: .leading)
        //.frame(minWidth: 520, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)
        .task { await viewModel.load() }
        .navigationTitle("Cronologia migrazioni")
    }

    private func migrationRow(_ migration: DatabaseMigration) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
            HStack(alignment: .firstTextBaseline) {
                Text(migration.name)
                    .font(.headline)
                    .textSelection(.enabled)
                Spacer()
                Text(migration.result.rawValue.capitalized)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(migration.result == .success ? .green : .red)
            }

            HStack {
                Text(migration.timestamp, format: .dateTime.year().month().day().hour().minute().second())
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if migration.appliedInCurrentSession {
                    Label("Applicata in questa sessione", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage = migration.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, AppDesignSystem.spacingSM)
    }
}

#Preview {
    MigrationHistoryView(
        databaseURL: FileManager.default.temporaryDirectory.appendingPathComponent("woa-preview.db"),
        migrationService: DatabaseMigrationService()
    )
}
