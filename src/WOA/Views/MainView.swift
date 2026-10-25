import SwiftUI

/// Main entry point view: database configuration required screen, or connected settings screen.
struct MainView: View {

    @StateObject private var settingsStore: AppSettingsStore
    @StateObject private var migrationService: DatabaseMigrationService
    @StateObject private var databaseManagementViewModel: DatabaseManagementViewModel
    @StateObject private var dataChangeCoordinator = DataChangeCoordinator()
    @State private var navigationPath: [NavigationRoute] = []

    init() {
        let settingsStore = AppSettingsStore()
        let migrationService = DatabaseMigrationService()
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _migrationService = StateObject(wrappedValue: migrationService)
        _databaseManagementViewModel = StateObject(
            wrappedValue: DatabaseManagementViewModel(
                settingsStore: settingsStore,
                migrationService: migrationService
            )
        )
    }

    var body: some View {
        MainNavigationView(
            path: $navigationPath,
            isConfigured: databaseManagementViewModel.isReadyForUse,
            appVersionLabel: appVersionLabel,
            onSearch: { navigationPath.append(.patientsSearch) }
        ) {
            DatabaseManagementView(
                viewModel: databaseManagementViewModel,
                settingsStore: settingsStore,
                onMigrationHistory: {
                    let path = settingsStore.settings.databaseConnection.path
                    guard !path.isEmpty else { return }
                    navigationPath.append(.migrationHistory(databaseURL: URL(fileURLWithPath: path)))
                },
                onResetConfiguration: {
                    navigationPath.removeAll()
                    databaseManagementViewModel.resetConfiguration()
                }
            )
        } destinationContent: { route in
                    switch route {
                    case .patientsSearch:
                        PazienteSearchView(
                            databasePath: settingsStore.settings.databaseConnection.path,
                            onAddPatient: {
                                let url = URL(fileURLWithPath: settingsStore.settings.databaseConnection.path)
                                navigationPath.append(.addPatient(databaseURL: url))
                            },
                            onOpenDetails: { patient in
                                let url = URL(fileURLWithPath: settingsStore.settings.databaseConnection.path)
                                navigationPath.append(.patientDetails(patientID: patient.id, databaseURL: url))
                            }
                        )
                    case .addPatient(let databaseURL):
                        PazienteAddView(
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
                        PazienteDetailView(
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
                            },
                            onEditPatient: {
                                navigationPath.append(.editPatient(patientID: patientID, databaseURL: databaseURL))
                            }
                        )
                    case .editPatient(let patientID, let databaseURL):
                        PazienteEditView(patientID: patientID,
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
                    case .consultoDetail(let consultoID, let patientID, let databaseURL):
                        ConsultoDetailView(
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
                            },
                            onEditConsulto: {
                                navigationPath.append(.editConsulto(consultoID: consultoID, patientID: patientID, databaseURL: databaseURL))
                            }
                        )
                    case .addConsultation(let patientID, let databaseURL):
                        ConsultoAddView(
                            patientID: patientID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onCancel: { if !navigationPath.isEmpty { navigationPath.removeLast() } },
                            onSuccess: {
                                if !navigationPath.isEmpty { navigationPath.removeLast() }
                            }
                        )
                    case .editConsulto(let consultoID, let patientID, let databaseURL):
                        ConsultoEditView(
                            consultoID: consultoID,
                            patientID: patientID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onCancel: { if !navigationPath.isEmpty { navigationPath.removeLast() } },
                            onSuccess: {
                                if !navigationPath.isEmpty { navigationPath.removeLast() }
                            }
                        )
                    case .addTreatment(let consultoID, let patientID, let databaseURL):
                        TrattamentoAddView(
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
                        TrattamentoDetailEditView(
                            treatmentID: treatmentID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onBackToConsulto: { if !navigationPath.isEmpty { navigationPath.removeLast() } }
                        )
                    case .addEvaluation(let consultoID, let patientID, let databaseURL):
                        ValutazioneAddView(
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
                        ValutazioneDetailEditView(
                            evaluationID: evaluationID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onBackToConsulto: { if !navigationPath.isEmpty { navigationPath.removeLast() } }
                        )
                    case .addExam(let consultoID, let patientID, let databaseURL):
                        EsameAddView(
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
                        EsameDetailEditView(
                            examID: examID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onBackToConsulto: { if !navigationPath.isEmpty { navigationPath.removeLast() } }
                        )
                    case .historyDetail(let historyID, let databaseURL):
                        AnamnesiRemotaDetailEditView(
                            historyID: historyID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onBackToPatient: { if !navigationPath.isEmpty { navigationPath.removeLast() } }
                        )
                    case .addHistory(let patientID, let databaseURL):
                        AnamnesiRemotaAddView(
                            patientID: patientID,
                            databaseFileURL: databaseURL,
                            dataChangeCoordinator: dataChangeCoordinator,
                            onCancel: { if !navigationPath.isEmpty { navigationPath.removeLast() } },
                            onSuccess: {
                                if !navigationPath.isEmpty { navigationPath.removeLast() }
                            }
                        )
                    case .migrationHistory(let databaseURL):
                        MigrationHistoryView(
                            databaseURL: databaseURL,
                            migrationService: migrationService
                        )
                    }
        }
        .onChange(of: databaseManagementViewModel.isConfigured) {
            if !databaseManagementViewModel.isConfigured {
                navigationPath.removeAll()
            }
        }

    }
    /// Bundle version from Info.plist (`CFBundleVersion`). Debug builds append `(next)`.
    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        #if DEBUG
        return "v\(version) (next)"
        #else
        return "v\(version)"
        #endif
    }

}
