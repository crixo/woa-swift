import SwiftUI

/// Main entry point view: database configuration required screen, or connected settings screen.
struct SettingsView: View {

    private enum NavigationRoute: Hashable {
        case patientsSearch
        case addPatient(databaseURL: URL)
        case patientDetails(PatientSearchResult)
    }

    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var selectorViewModel = DatabaseSelectorViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationDestination(for: NavigationRoute.self) { route in
                    switch route {
                    case .patientsSearch:
                        PatientsSearchView(
                            databasePath: settingsViewModel.allSettings.databaseConnection.path,
                            onAddPatient: {
                                let url = URL(fileURLWithPath: settingsViewModel.allSettings.databaseConnection.path)
                                navigationPath.append(.addPatient(databaseURL: url))
                            },
                            onOpenDetails: { patient in
                                navigationPath.append(.patientDetails(patient))
                            }
                        )
                    case .addPatient(let databaseURL):
                        AddPatientView(
                            databaseFileURL: databaseURL,
                            onCancel: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            },
                            onSuccess: {
                                if !navigationPath.isEmpty {
                                    navigationPath.removeLast()
                                }
                            }
                        )
                    case .patientDetails(let patient):
                        PatientDetailsView(patient: patient)
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Home") {
                    navigationPath.removeAll()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Back") {
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast()
                    }
                }
                .disabled(navigationPath.isEmpty)
            }

            ToolbarItem(placement: .automatic) {
                Button("Patients Search") {
                    guard settingsViewModel.isConfigured else { return }
                    navigationPath.append(.patientsSearch)
                }
                .disabled(!settingsViewModel.isConfigured)
            }

            ToolbarItem(placement: .automatic) {
                Button("Re-select Database") {
                    navigationPath.removeAll()
                    settingsViewModel.resetConfiguration()
                }
                .disabled(!settingsViewModel.isConfigured)
            }
        }
        .frame(minWidth: 420, minHeight: 320)
        .onAppear {
            settingsViewModel.loadSettings()
            if !settingsViewModel.isConfigured {
                navigationPath.removeAll()
            }
        }
        .onChange(of: settingsViewModel.isConfigured) { isConfigured in
            if !isConfigured {
                navigationPath.removeAll()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
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
        }
    }
}

private struct PatientDetailsView: View {
    let patient: PatientSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Patient Details")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(patient.details, id: \ .self) { detail in
                    Text(detail)
                        .font(.body)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
