import SwiftUI

/// Layout constants specific to the patients search screen.
private enum LayoutMetrics {
    static let contentSpacing: CGFloat = 16
    static let searchFieldMinWidth: CGFloat = 200
    static let searchFieldMaxWidth: CGFloat = 320
    static let headerSpacing: CGFloat = 8
    static let rowSpacing: CGFloat = 6
    static let contentMaxWidth: CGFloat = 760
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

                TextField("Search by name", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: LayoutMetrics.searchFieldMinWidth, maxWidth: LayoutMetrics.searchFieldMaxWidth, alignment: .leading)
                    .onChange(of: viewModel.searchText) { _ in
                        viewModel.triggerSearchIfReady()
                    }
                    .onSubmit {
                        viewModel.search()
                    }

                if !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
                    Text("Type at least 3 characters to search.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isSearching {
                    ProgressView("Searching patients...")
                } else {
                    Text("\(viewModel.resultCount) result(s) found")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
                    !viewModel.isSearching &&
                    viewModel.results.isEmpty {
                    Text("No patients found.")
                        .foregroundStyle(.secondary)
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
    }

    private var wideHeader: some View {
        HStack {
            Text("Patients Search")
                .font(.title2)
                .bold()

            Spacer()

            addPatientButton
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.headerSpacing) {
            Text("Patients Search")
                .font(.title2)
                .bold()

            addPatientButton
        }
    }

    private var addPatientButton: some View {
        Button(action: onAddPatient) {
            Label("Add Patient", systemImage: "person.badge.plus")
        }
        .buttonStyle(.bordered)
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
            Text(patient.fullName)
                .font(.headline)

            Text("Age: \(patient.ageText)")
                .font(.subheadline)

            Text("Address: \(patient.address.isEmpty ? "Not available" : patient.address)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button("View details") { openDetails(patient) }
                .buttonStyle(.link)
        }
        .padding(.vertical, 4)
    }

    private func compactResultRow(_ patient: PatientSearchResult) -> some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.rowSpacing) {
            Text(patient.fullName)
                .font(.headline)

            Text("Age: \(patient.ageText)")
                .font(.subheadline)

            Text("Address: \(patient.address.isEmpty ? "Not available" : patient.address)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("View details") { openDetails(patient) }
                .buttonStyle(.link)
        }
        .padding(.vertical, 4)
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
