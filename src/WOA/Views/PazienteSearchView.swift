import SwiftUI

/// Layout constants specific to the patients search screen.
private enum LayoutMetrics2 {
    static let contentSpacing: CGFloat = AppDesignSystem.spacingLG
    static let searchFieldMinWidth: CGFloat = 200
    static let headerSpacing: CGFloat = AppDesignSystem.spacingSM
    static let rowSpacing: CGFloat = AppDesignSystem.spacingXS
    static let contentMaxWidth: CGFloat = AppDesignSystem.panelMaxWidth
}


/// Search and browse patients by name; details and add patient are rendered inline by the root navigation stack.
struct PazienteSearchView: View {

    let databasePath: String
    let onAddPatient: () -> Void
    let onOpenDetails: (PatientSearchResult) -> Void
    let onOpenPatientDetails: (Int) -> Void

    @StateObject private var viewModel: PazienteSearchViewModel
    @State private var showLastModifiedPatients = false

    init(
        databasePath: String,
        onAddPatient: @escaping () -> Void = {},
        onOpenDetails: @escaping (PatientSearchResult) -> Void = { _ in },
        onOpenPatientDetails: @escaping (Int) -> Void = { _ in }
    ) {
        self.databasePath = databasePath
        self.onAddPatient = onAddPatient
        self.onOpenDetails = onOpenDetails
        self.onOpenPatientDetails = onOpenPatientDetails
        _viewModel = StateObject(wrappedValue: PazienteSearchViewModel(databasePath: databasePath))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutMetrics2.contentSpacing) {
                ViewThatFits(in: .horizontal) {
                    wideHeader
                    compactHeader
                }

                if showLastModifiedPatients {
                    LastModifiedPatientsView(
                        patients: viewModel.lastModifiedPatients,
                        isLoading: viewModel.isLoadingLastModifiedPatients,
                        errorMessage: viewModel.lastModifiedPatientsError,
                        onOpenPatientDetails: onOpenPatientDetails
                    )
                }
                
                searchPanel

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .appErrorText()
                }

                if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
                    !viewModel.isSearching &&
                    viewModel.results.isEmpty {
                    ContentUnavailableView("Nessun paziente trovato", systemImage: "person.slash", description: Text("Prova un nome o un termine di ricerca diverso."))
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.results) { patient in
                        resultRow(patient)
                    }
                }
            }
            .padding()
            .frame(maxWidth: LayoutMetrics2.contentMaxWidth, alignment: .leading)
        }
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)
        .navigationTitle("Ricerca pazienti")
        .onAppear {
            viewModel.loadLastModifiedPatients()
        }
    }

    private var wideHeader: some View {
        HStack {
            headerTitle

            Spacer()

            addPatientButton
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics2.headerSpacing) {
            headerTitle

            addPatientButton
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trova un paziente per nome per visualizzare la sua scheda.")
                .font(.title2.weight(.semibold))
        }
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
            Label("Cerca pazienti", systemImage: "magnifyingglass")
                .font(.headline)

            TextField("Cerca per nome", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: LayoutMetrics2.searchFieldMinWidth, maxWidth: .infinity, alignment: .leading)
                .onChange(of: viewModel.searchText) {
                    viewModel.triggerSearchIfReady()
                }
                .onSubmit {
                    viewModel.search()
                }

            Button {
                viewModel.search()
            } label: {
                Label("Cerca", systemImage: "magnifyingglass")
            }
            .appSearchButton()

            ViewThatFits(in: .horizontal) {
                HStack {
                    searchHint
                    Spacer()
                    resultSummary
                }
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                    searchHint
                    resultSummary
                }
            }
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }

    @ViewBuilder
    private var searchHint: some View {
        if !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            Text("Digita almeno 3 caratteri per cercare.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var resultSummary: some View {
        if viewModel.isSearching {
            ProgressView("Ricerca pazienti...")
        } else {
            Label("\(viewModel.resultCount) risultato/i trovato/i", systemImage: "person.2")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var addPatientButton: some View {
        HStack(spacing: AppDesignSystem.spacingSM) {
            Button {
                showLastModifiedPatients.toggle()
                if showLastModifiedPatients {
                    viewModel.loadLastModifiedPatients()
                }
            } label: {
                Label(showLastModifiedPatients ? "Nascondi pazienti recenti" : "Mostra gli ultimi \(AppSettings.AppConstants.lastModifiedPatientsLimit) pazienti modificati", systemImage: "clock.arrow.circlepath")
            }
            .appSecondaryButton()

            Button(action: onAddPatient) {
                Label("Aggiungi paziente", systemImage: "person.badge.plus")
            }
            .appAddButton()
        }
    }

    @ViewBuilder
    private func resultRow(_ patient: PatientSearchResult) -> some View {
        ViewThatFits(in: .horizontal) {
            wideResultRow(patient)
            compactResultRow(patient)
        }
    }

    private func wideResultRow(_ patient: PatientSearchResult) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LayoutMetrics2.contentSpacing) {
            patientSummary(patient)

            Spacer()

            detailsButton(for: patient)
        }
        .appSection()
    }

    private func compactResultRow(_ patient: PatientSearchResult) -> some View {
        VStack(alignment: .leading, spacing: LayoutMetrics2.rowSpacing) {
            patientSummary(patient)

            detailsButton(for: patient)
        }
        .appSection()
    }

    private func patientSummary(_ patient: PatientSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(patient.fullName)
                .font(.headline)
            Text("Età: \(patient.ageText)")
                .font(.subheadline)
            Text(patient.address.isEmpty ? "Indirizzo non disponibile" : patient.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .layoutPriority(1)
    }

    private func detailsButton(for patient: PatientSearchResult) -> some View {
        Button {
            openDetails(patient)
        } label: {
            Label("Vedi dettagli", systemImage: "arrow.right.circle")
        }
        .appSecondaryButton()
    }

    private func openDetails(_ patient: PatientSearchResult) {
        viewModel.openDetails(patient)
        onOpenDetails(patient)
    }
}

#Preview("Compatto") {
    PazienteSearchView(databasePath: "/tmp/preview.db")
        .frame(width: 420, height: 500)
}

#Preview("Standard") {
    PazienteSearchView(databasePath: "/tmp/preview.db")
        .frame(width: 700, height: 600)
}

#Preview("Wide") {
    PazienteSearchView(databasePath: "/tmp/preview.db")
        .frame(width: 1100, height: 700)
}
