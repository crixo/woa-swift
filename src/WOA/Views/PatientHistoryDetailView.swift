import SwiftUI

/// Layout constants for this view.
private enum LayoutMetrics {
    static let formMaxWidth: CGFloat = 560
}

/// Wide: info leading, actions trailing. Compact: info above, actions below.
@ViewBuilder
private func responsiveHeader<Info: View, Actions: View>(
    @ViewBuilder info: () -> Info,
    @ViewBuilder actions: () -> Actions
) -> some View {
    ViewThatFits(in: .horizontal) {
        HStack(alignment: .top) {
            info()
            Spacer()
            actions()
        }
        VStack(alignment: .leading, spacing: 8) {
            info()
            HStack {
                actions()
            }
        }
    }
}

struct PatientHistoryDetailView: View {
    let onBackToPatient: () -> Void
    @StateObject private var viewModel: RemoteHistoryDetailViewModel
    @State private var isEditMode = false

    init(historyID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onBackToPatient: @escaping () -> Void) {
        self.onBackToPatient = onBackToPatient
        _viewModel = StateObject(wrappedValue: RemoteHistoryDetailViewModel(historyID: historyID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.history == nil {
                ProgressView("Loading health history...")
            } else if let history = viewModel.history {
                if let saveSucceeded = viewModel.saveSucceeded {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: saveSucceeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(saveSucceeded ? .green : .red)
                                .font(.title2)
                            Text(saveSucceeded ? "Health history saved successfully" : "Failed to save health history")
                                .font(.body)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(saveSucceeded ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        Button(action: onBackToPatient) {
                            Text("Back to Patient")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if isEditMode {
                                Form {
                                    DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
                                    Picker("Type", selection: $viewModel.request.typeID) {
                                        ForEach(viewModel.types) { type in
                                            Text(type.name).tag(type.id)
                                        }
                                    }
                                    TextField("Description", text: $viewModel.request.description, axis: .vertical)
                                    if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundStyle(.red) }
                                    HStack {
                                        Button("Cancel") { isEditMode = false }
                                        Spacer()
                                        Button("Save") { Task { await viewModel.save() } }
                                            .disabled(viewModel.isSaving)
                                    }
                                }
                            } else {
                                responsiveHeader {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("ID \(history.id)").font(.headline).bold()
                                        Text(history.date?.formatted(date: .long, time: .omitted) ?? "No date").foregroundStyle(.secondary)
                                        Text("Type: \(history.typeName ?? "Not available")").foregroundStyle(.secondary)
                                        Text(history.description ?? "No description")
                                    }
                                } actions: {
                                    Button("✏️") { isEditMode = true }
                                    Button("🗑️", role: .destructive) { viewModel.showDeleteConfirmation = true }
                                        .disabled(viewModel.isDeleting)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding()
                        .frame(maxWidth: LayoutMetrics.formMaxWidth, alignment: .leading)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.square")
                    Text("Health history not found")
                }
            }
        }
        .navigationTitle("Remote Health History")
        .onAppear {
            Task { await viewModel.load() }
        }
        .confirmationDialog("Delete this health history?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() { onBackToPatient() }
                }
            }
        }
    }
}

#Preview("Compact") {
    PatientHistoryDetailView(
        historyID: 1,
        databaseFileURL: URL(fileURLWithPath: "/tmp/preview.db"),
        dataChangeCoordinator: DataChangeCoordinator(),
        onBackToPatient: {}
    )
    .frame(width: 380, height: 500)
}

#Preview("Wide") {
    PatientHistoryDetailView(
        historyID: 1,
        databaseFileURL: URL(fileURLWithPath: "/tmp/preview.db"),
        dataChangeCoordinator: DataChangeCoordinator(),
        onBackToPatient: {}
    )
    .frame(width: 1000, height: 600)
}
