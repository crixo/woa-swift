import SwiftUI

enum NavigationRoute: Hashable {
    case patientsSearch
    case addPatient(databaseURL: URL)
    case patientDetails(patientID: Int, databaseURL: URL)
    case editPatient(patientID: Int, databaseURL: URL)
    case consultoDetail(consultoID: Int, patientID: Int, databaseURL: URL)
    case addConsultation(patientID: Int, databaseURL: URL)
    case editConsulto(consultoID: Int, patientID: Int, databaseURL: URL)
    case addTreatment(consultoID: Int, patientID: Int, databaseURL: URL)
    case treatmentDetail(treatmentID: Int, databaseURL: URL)
    case addEvaluation(consultoID: Int, patientID: Int, databaseURL: URL)
    case evaluationDetail(evaluationID: Int, databaseURL: URL)
    case addExam(consultoID: Int, patientID: Int, databaseURL: URL)
    case examDetail(examID: Int, databaseURL: URL)
    case historyDetail(historyID: Int, databaseURL: URL)
    case addHistory(patientID: Int, databaseURL: URL)
}

struct MainNavigationView<RootContent: View, DestinationContent: View>: View {
    @Binding var path: [NavigationRoute]
    let isConfigured: Bool
    let appVersionLabel: String
    let onSearch: () -> Void
    @ViewBuilder let rootContent: () -> RootContent
    @ViewBuilder let destinationContent: (NavigationRoute) -> DestinationContent

    var body: some View {
        NavigationStack(path: $path) {
            rootContent()
                .navigationDestination(for: NavigationRoute.self) { route in
                    destinationContent(route)
                }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    if !path.isEmpty {
                        path.removeLast()
                    }
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .labelStyle(.iconOnly)
                .disabled(path.isEmpty)
                .appSecondaryButton()
                .help("Back")

                Button {
                    path.removeAll()
                } label: {
                    Label("Home", systemImage: "house")
                }
                .labelStyle(.iconOnly)
                .disabled(path.isEmpty)
                .help("Home")
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: AppDesignSystem.spacingSM) {
                    Text("WOA")
                        .font(.headline.weight(.bold))
                    Text("patients database … \(appVersionLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)
                .padding(.horizontal, AppDesignSystem.spacingMD)
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: onSearch) {
                    Label("Patients Search", systemImage: "person.3.fill")
                }
                .labelStyle(.titleAndIcon)
                .disabled(!isConfigured)
                .appSearchButton()
                .frame(minWidth: 150)
            }
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}