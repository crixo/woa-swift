import SwiftUI

struct DatabaseManagementView: View {
    @ObservedObject var viewModel: DatabaseManagementViewModel
    @ObservedObject var settingsStore: AppSettingsStore
    let onResetConfiguration: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingXL) {
            if viewModel.isLoading {
                ProgressView("Loading configuration...")
                    .appCard(padding: AppDesignSystem.spacingLG)
            } else if viewModel.didImportSuccessfully {
                TableStatusView(tables: viewModel.importedTables, onContinue: viewModel.continueAfterImport)
                .appCard(padding: AppDesignSystem.spacingLG)
            } else if viewModel.isConfigured {
                LaunchScreenView(
                    tables: viewModel.tableStats,
                    settings: settingsStore.settings,
                    settingsFilePath: settingsStore.settingsFilePath,
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
}