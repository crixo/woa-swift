import SwiftUI

/// Layout constants specific to the patients search screen.
private enum LayoutMetrics {
    static let contentSpacing: CGFloat = AppDesignSystem.spacingLG
    static let searchFieldMinWidth: CGFloat = 200
    static let headerSpacing: CGFloat = AppDesignSystem.spacingSM
    static let rowSpacing: CGFloat = AppDesignSystem.spacingXS
    static let contentMaxWidth: CGFloat = AppDesignSystem.panelMaxWidth
}

/// Search and browse patients by name; details and add patient are rendered inline by the root navigation stack.
struct PatientsSearchView: View {

    let databasePath: String
    let onAddPatient: () -> Void
    let onOpenDetails: (PatientSearchResult) -> Void

    @StateObject private var viewModel: PatientsSearchViewModel

    init(databasePath: String, onAddPatient: @escaping () -> Void = {}, onOpenDetails: @escaping (PatientSearchResult) -> Void = { _ in }) {
        self.databasePath = databasePath
        self.onAddPatient = onAddPatient
        self.onOpenDetails = onOpenDetails
        _viewModel = StateObject(wrappedValue: PatientsSearchViewModel(databasePath: databasePath))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutMetrics.contentSpacing) {
                ViewThatFits(in: .horizontal) {
                    wideHeader
                    compactHeader
                }

                searchPanel

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .appErrorText()
                }

                if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
                    !viewModel.isSearching &&
                    viewModel.results.isEmpty {
                    ContentUnavailableView("No patients found", systemImage: "person.slash", description: Text("Try a different name or search term."))
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.results) { patient in
                        resultRow(patient)
                    }
                }
            }
            .padding()
            .frame(maxWidth: LayoutMetrics.contentMaxWidth, alignment: .leading)
        }
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Patient Search")
    }

    private var wideHeader: some View {
        HStack {
            headerTitle

            Spacer()

            addPatientButton
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.headerSpacing) {
            headerTitle

            addPatientButton
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Find a patient by name to view their record.")
                .font(.title2.weight(.semibold))
        }
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
            Label("Search patients", systemImage: "magnifyingglass")
                .font(.headline)

            TextField("Search by name", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: LayoutMetrics.searchFieldMinWidth, maxWidth: .infinity, alignment: .leading)
                .onChange(of: viewModel.searchText) {
                    viewModel.triggerSearchIfReady()
                }
                .onSubmit {
                    viewModel.search()
                }

            Button {
                viewModel.search()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
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
            Text("Type at least 3 characters to search.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var resultSummary: some View {
        if viewModel.isSearching {
            ProgressView("Searching patients...")
        } else {
            Label("\(viewModel.resultCount) result(s) found", systemImage: "person.2")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var addPatientButton: some View {
        Button(action: onAddPatient) {
            Label("Add Patient", systemImage: "person.badge.plus")
        }
        .appAddButton()
    }

    @ViewBuilder
    private func resultRow(_ patient: PatientSearchResult) -> some View {
        ViewThatFits(in: .horizontal) {
            wideResultRow(patient)
            compactResultRow(patient)
        }
    }

    private func wideResultRow(_ patient: PatientSearchResult) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LayoutMetrics.contentSpacing) {
            patientSummary(patient)

            Spacer()

            detailsButton(for: patient)
        }
        .appSection()
    }

    private func compactResultRow(_ patient: PatientSearchResult) -> some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.rowSpacing) {
            patientSummary(patient)

            detailsButton(for: patient)
        }
        .appSection()
    }

    private func patientSummary(_ patient: PatientSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(patient.fullName)
                .font(.headline)
            Text("Age: \(patient.ageText)")
                .font(.subheadline)
            Text(patient.address.isEmpty ? "Address not available" : patient.address)
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
            Label("View details", systemImage: "arrow.right.circle")
        }
        .appSecondaryButton()
    }

    private func openDetails(_ patient: PatientSearchResult) {
        viewModel.openDetails(patient)
        onOpenDetails(patient)
    }
}

#Preview("Compact") {
    PatientsSearchView(databasePath: "/tmp/preview.db")
        .frame(width: 420, height: 500)
}

#Preview("Standard") {
    PatientsSearchView(databasePath: "/tmp/preview.db")
        .frame(width: 700, height: 600)
}

#Preview("Wide") {
    PatientsSearchView(databasePath: "/tmp/preview.db")
        .frame(width: 1100, height: 700)
}
