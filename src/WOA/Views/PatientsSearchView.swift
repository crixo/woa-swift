import SwiftUI

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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Patients Search")
                    .font(.title2)
                    .bold()

                Spacer()

                Button(action: onAddPatient) {
                    Label("Add Patient", systemImage: "person.badge.plus")
                }
                .buttonStyle(.bordered)
            }

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
                                onOpenDetails(patient)
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
    }
}
