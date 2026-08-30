import SwiftUI

/// Main entry point view: database configuration required screen, or connected settings screen.
struct SettingsView: View {

    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var selectorViewModel = DatabaseSelectorViewModel()
    @State private var showPatientSearch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WOA")
                .font(.largeTitle)
                .bold()

            if settingsViewModel.isLoading {
                ProgressView()
            } else if selectorViewModel.didImportSuccessfully {
                TableStatusView(tables: selectorViewModel.importedTables) {
                    settingsViewModel.loadSettings()
                    selectorViewModel.didImportSuccessfully = false
                }
            } else if settingsViewModel.isConfigured {
                connectedContent
            } else {
                notConfiguredContent
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 320)
        .onAppear {
            settingsViewModel.loadSettings()
        }
    }

    private var notConfiguredContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Database Configuration Required")
                .font(.headline)
            DatabaseSelectorView(viewModel: selectorViewModel)
        }
    }

    private var connectedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Database Connection Status: ✅ Connected")
                .font(.headline)

            if let lastValidated = settingsViewModel.allSettings.databaseConnection.lastValidated {
                Text("Last validated: \(lastValidated.formatted())")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(settingsViewModel.tableStats) { table in
                    Text("- \(table.name) (\(table.recordCount))")
                }
            }

            HStack(spacing: 12) {
                Button("Patients Search") {
                    showPatientSearch = true
                }

                Button("Re-select Database") {
                    settingsViewModel.resetConfiguration()
                }
            }
        }
        .sheet(isPresented: $showPatientSearch) {
            PatientsSearchView(databasePath: settingsViewModel.allSettings.databaseConnection.path)
        }
    }
}
