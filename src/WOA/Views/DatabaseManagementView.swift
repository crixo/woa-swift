import SwiftUI

struct DatabaseManagementView: View {
    @ObservedObject var viewModel: DatabaseManagementViewModel
    @ObservedObject var settingsStore: AppSettingsStore
    let onMigrationHistory: () -> Void
    let onResetConfiguration: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingXL) {
            if viewModel.isLoading {
                ProgressView("Loading configuration...")
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
            Text("Database Configuration Required")
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
            Label("Database Migration Required", systemImage: "exclamationmark.triangle.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.orange)

            Text("The database could not be updated. WOA cannot continue until the migration succeeds.")
                .font(.body)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Button("Retry Migrations", systemImage: "arrow.clockwise") {
                viewModel.retryMigrations()
            }
            .appPrimaryButton()

            if canGrantFolderAccess {
                Text("SQLite needs permission to the database's containing folder to create or open sibling journal files.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Grant Database Folder Access and Retry", systemImage: "folder.badge.gearshape") {
                    onGrantFolderAccess()
                }
                .appSecondaryButton()
            }

            if canCopyToApplicationSupport {
                Text("If macOS blocks SQLite from accessing journal files beside the selected database, copy it into Application Support and retry.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Copy to Application Support and Retry", systemImage: "doc.on.doc") {
                    onCopyToApplicationSupport()
                }
                .appSecondaryButton()
            }

            Button("Choose Another Database", systemImage: "folder") {
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