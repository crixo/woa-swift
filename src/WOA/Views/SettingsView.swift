import SwiftUI

/// Main entry point view: database configuration required screen, or connected settings screen.
struct SettingsView: View {

    private enum NavigationRoute: Hashable {
        case patientsSearch
        case addPatient(databaseURL: URL)
        case patientDetails(patientID: Int, databaseURL: URL)
        case consultoDetail(consultoID: Int, patientID: Int, databaseURL: URL)
        case addConsultation(patientID: Int, databaseURL: URL)
        case addTreatment(consultoID: Int, patientID: Int, databaseURL: URL)
        case treatmentDetail(treatmentID: Int, databaseURL: URL)
        case addEvaluation(consultoID: Int, patientID: Int, databaseURL: URL)
        case evaluationDetail(evaluationID: Int, databaseURL: URL)
        case addExam(consultoID: Int, patientID: Int, databaseURL: URL)
        case examDetail(examID: Int, databaseURL: URL)
        case historyDetail(historyID: Int, databaseURL: URL)
        case addHistory(patientID: Int, databaseURL: URL)
    }

    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var selectorViewModel = DatabaseSelectorViewModel()
    @StateObject private var dataChangeCoordinator = DataChangeCoordinator()
    @State private var navigationPath: [NavigationRoute] = []

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
                                let url = URL(fileURLWithPath: settingsViewModel.allSettings.databaseConnection.path)
                                navigationPath.append(.patientDetails(patientID: patient.id, databaseURL: url))
                            }
                        )
                    case .addPatient(let databaseURL):
                        AddPatientView(
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
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
                    case .patientDetails(let patientID, let databaseURL):
                        PatientDetailView(
                            patientID: patientID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onOpenConsultation: { consultationID in
                                navigationPath.append(.consultoDetail(consultoID: consultationID, patientID: patientID, databaseURL: databaseURL))
                            },
                            onAddConsultation: {
                                navigationPath.append(.addConsultation(patientID: patientID, databaseURL: databaseURL))
                            },
                            onOpenHistory: { historyID in
                                navigationPath.append(.historyDetail(historyID: historyID, databaseURL: databaseURL))
                            },
                            onAddHistory: {
                                navigationPath.append(.addHistory(patientID: patientID, databaseURL: databaseURL))
                            },
                            onDeleted: {
                                if !navigationPath.isEmpty { navigationPath.removeLast() }
                            }
                        )
                    case .consultoDetail(let consultoID, let patientID, let databaseURL):
                        ConsultoPatientDetailView(
                            consultoID: consultoID,
                            patientID: patientID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onOpenTreatment: { treatmentID in
                                navigationPath.append(.treatmentDetail(treatmentID: treatmentID, databaseURL: databaseURL))
                            },
                            onAddTreatment: {
                                navigationPath.append(.addTreatment(consultoID: consultoID, patientID: patientID, databaseURL: databaseURL))
                            },
                            onOpenEvaluation: { evaluationID in
                                navigationPath.append(.evaluationDetail(evaluationID: evaluationID, databaseURL: databaseURL))
                            },
                            onAddEvaluation: {
                                navigationPath.append(.addEvaluation(consultoID: consultoID, patientID: patientID, databaseURL: databaseURL))
                            },
                            onOpenExam: { examID in
                                navigationPath.append(.examDetail(examID: examID, databaseURL: databaseURL))
                            },
                            onAddExam: {
                                navigationPath.append(.addExam(consultoID: consultoID, patientID: patientID, databaseURL: databaseURL))
                            },
                            onDeleted: {
                                if !navigationPath.isEmpty { navigationPath.removeLast() }
                            }
                        )
                    case .addConsultation(let patientID, let databaseURL):
                        AddConsultationView(
                            patientID: patientID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onCancel: { if !navigationPath.isEmpty { navigationPath.removeLast() } },
                            onSuccess: {
                                if !navigationPath.isEmpty { navigationPath.removeLast() }
                            }
                        )
                    case .addTreatment(let consultoID, let patientID, let databaseURL):
                        AddTreatmentView(
                            consultoID: consultoID,
                            patientID: patientID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onCancel: { if !navigationPath.isEmpty { navigationPath.removeLast() } },
                            onSuccess: {
                                if !navigationPath.isEmpty { navigationPath.removeLast() }
                            }
                        )
                    case .treatmentDetail(let treatmentID, let databaseURL):
                        TreatmentDetailEditView(
                            treatmentID: treatmentID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onBackToConsulto: { if !navigationPath.isEmpty { navigationPath.removeLast() } }
                        )
                    case .addEvaluation(let consultoID, let patientID, let databaseURL):
                        AddEvaluationView(
                            consultoID: consultoID,
                            patientID: patientID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onCancel: { if !navigationPath.isEmpty { navigationPath.removeLast() } },
                            onSuccess: {
                                if !navigationPath.isEmpty { navigationPath.removeLast() }
                            }
                        )
                    case .evaluationDetail(let evaluationID, let databaseURL):
                        EvaluationDetailEditView(
                            evaluationID: evaluationID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onBackToConsulto: { if !navigationPath.isEmpty { navigationPath.removeLast() } }
                        )
                    case .addExam(let consultoID, let patientID, let databaseURL):
                        AddExamView(
                            consultoID: consultoID,
                            patientID: patientID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onCancel: { if !navigationPath.isEmpty { navigationPath.removeLast() } },
                            onSuccess: {
                                if !navigationPath.isEmpty { navigationPath.removeLast() }
                            }
                        )
                    case .examDetail(let examID, let databaseURL):
                        ExamDetailEditView(
                            examID: examID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onBackToConsulto: { if !navigationPath.isEmpty { navigationPath.removeLast() } }
                        )
                    case .historyDetail(let historyID, let databaseURL):
                        PatientHistoryDetailView(historyID: historyID, databaseFileURL: databaseURL)
                    case .addHistory(let patientID, let databaseURL):
                        AddRemoteHistoryView(
                            patientID: patientID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onCancel: { if !navigationPath.isEmpty { navigationPath.removeLast() } },
                            onSuccess: {
                                if !navigationPath.isEmpty { navigationPath.removeLast() }
                            }
                        )
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
