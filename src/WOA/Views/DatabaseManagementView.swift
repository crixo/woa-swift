import SwiftUI

struct DatabaseManagementView: View {
    @ObservedObject var viewModel: DatabaseManagementViewModel
    @ObservedObject var settingsStore: AppSettingsStore
    let onMigrationHistory: () -> Void
    let onResetConfiguration: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingXL) {
            if viewModel.isLoading {
                ProgressView("Caricamento configurazione...")
                    .appCard(padding: AppDesignSystem.spacingLG)
            } else if let migrationError = viewModel.migrationError {
                migrationFailureContent(
                    migrationError,
                    onCopyToApplicationSupport: viewModel.copyActiveDatabaseToApplicationSupportAndRetry,
                    canCopyToApplicationSupport: viewModel.canCopyActiveDatabaseToApplicationSupport,
                    onGrantFolderAccess: viewModel.grantDatabaseFolderAccessAndRetry,
                    canGrantFolderAccess: viewModel.canGrantDatabaseFolderAccess,
                    onReselectDatabase: onResetConfiguration
                )
            } else if viewModel.didImportSuccessfully {
                TableStatusView(tables: viewModel.importedTables, onContinue: viewModel.continueAfterImport)
                .appCard(padding: AppDesignSystem.spacingLG)
            } else if viewModel.isConfigured {
                LaunchScreenView(
                    tables: viewModel.tableStats,
                    sessionMigrations: viewModel.sessionMigrations,
                    migrationHistoryError: viewModel.migrationHistoryError,
                    settings: settingsStore.settings,
                    settingsFilePath: settingsStore.settingsFilePath,
                    onMigrationHistory: onMigrationHistory,
                    onReselectDatabase: onResetConfiguration
                )
            } else {
                notConfiguredContent
            }
        }
        .padding()
        .onAppear(perform: viewModel.loadSettings)
    }

    private var notConfiguredContent: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
            Text("Configurazione database richiesta")
                .font(.title2.weight(.semibold))

            DatabaseSelectorView(viewModel: viewModel)
                .appPanel(padding: AppDesignSystem.spacingLG)
        }
    }

    private func migrationFailureContent(
        _ message: String,
        onCopyToApplicationSupport: @escaping () -> Void,
        canCopyToApplicationSupport: Bool,
        onGrantFolderAccess: @escaping () -> Void,
        canGrantFolderAccess: Bool,
        onReselectDatabase: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
            Label("Migrazione database richiesta", systemImage: "exclamationmark.triangle.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.orange)

            Text("Il database non è stato aggiornato. WOA non può continuare finché la migrazione non riesce.")
                .font(.body)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Button("Riprova migrazioni", systemImage: "arrow.clockwise") {
                viewModel.retryMigrations()
            }
            .appPrimaryButton()

            if canGrantFolderAccess {
                Text("SQLite necessita di autorizzazione alla cartella contenente il database per creare o aprire i file journal secondari.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Concedi accesso alla cartella del database e riprova", systemImage: "folder.badge.gearshape") {
                    onGrantFolderAccess()
                }
                .appSecondaryButton()
            }

            if canCopyToApplicationSupport {
                Text("Se macOS blocca SQLite dall'accesso ai file journal accanto al database selezionato, copialo in Application Support e riprova.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Copia in Application Support e riprova", systemImage: "doc.on.doc") {
                    onCopyToApplicationSupport()
                }
                .appSecondaryButton()
            }

            Button("Scegli un altro database", systemImage: "folder") {
                onReselectDatabase()
            }
            .appSecondaryButton()
        }
        .frame(maxWidth: 680, alignment: .leading)
        .padding(AppDesignSystem.spacingXL)
        .appCard(padding: AppDesignSystem.spacingLG)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}