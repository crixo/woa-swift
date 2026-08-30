import SwiftUI

/// Search and browse patients by name; results can display a details popup.
struct PatientsSearchView: View {

    let databasePath: String

    @StateObject private var viewModel: PatientsSearchViewModel

    init(databasePath: String) {
        self.databasePath = databasePath
        _viewModel = StateObject(wrappedValue: PatientsSearchViewModel(databasePath: databasePath))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Patients Search")
                .font(.title2)
                .bold()

            TextField("Search by name", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
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

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.results) { patient in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(patient.fullName)
                                .font(.headline)

                            Text("Age: \(patient.ageText)")
                                .font(.subheadline)

                            Text("Address: \(patient.address.isEmpty ? "Not available" : patient.address)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button("View details") {
                                viewModel.openDetails(patient)
                            }
                            .buttonStyle(.link)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .padding()
        .frame(minWidth: 520, minHeight: 420)
        .sheet(item: $viewModel.selectedPatient) { patient in
            PatientDetailsSheet(patient: patient)
        }
    }
}

private struct PatientDetailsSheet: View {

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
        .frame(width: 360, alignment: .leading)
    }
}
