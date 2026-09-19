import SwiftUI

/// Layout constants for this view.
private enum LayoutMetrics {
    static let formMaxWidth: CGFloat = 560
    static let readableContentMaxWidth: CGFloat = 760
}

private func infoPill(_ text: String) -> some View {
    Text(text)
        .font(.caption.weight(.semibold))
        .padding(.horizontal, AppDesignSystem.spacingSM)
        .padding(.vertical, AppDesignSystem.spacingXS)
        .foregroundStyle(.secondary)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
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
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
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
                    VStack(spacing: AppDesignSystem.spacingLG) {
                        HStack(spacing: AppDesignSystem.spacingSM) {
                            Image(systemName: saveSucceeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(saveSucceeded ? .green : .red)
                                .font(.title2)
                            Text(saveSucceeded ? "Health history saved successfully" : "Failed to save health history")
                                .font(.body.weight(.medium))
                        }
                        .padding(AppDesignSystem.spacingLG)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((saveSucceeded ? Color.green : Color.red).opacity(0.1), in: RoundedRectangle(cornerRadius: AppDesignSystem.cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesignSystem.cardRadius, style: .continuous)
                                .stroke((saveSucceeded ? Color.green : Color.red).opacity(0.3), lineWidth: 1)
                        )

                        Spacer()

                        Button(action: onBackToPatient) {
                            Text("Back to Patient")
                                .frame(maxWidth: .infinity)
                        }
                        .appPrimaryButton()
                        .padding(.horizontal)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                            if isEditMode {
                                Form {
                                    Section("Health history details") {
                                        DatePicker("Date", selection: $viewModel.request.date, displayedComponents: .date)
                                        Picker("Type", selection: $viewModel.request.typeID) {
                                            ForEach(viewModel.types) { type in
                                                Text(type.name).tag(type.id)
                                            }
                                        }
                                        TextField("Description", text: $viewModel.request.description, axis: .vertical)
                                    }

                                    if let errorMessage = viewModel.errorMessage {
                                        Section {
                                            Text(errorMessage)
                                                .appErrorText()
                                        }
                                    }

                                    Section {
                                        VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
                                            ViewThatFits(in: .horizontal) {
                                                HStack(spacing: AppDesignSystem.spacingSM) {
                                                    Button("Cancel") { isEditMode = false }
                                                        .appSecondaryButton()
                                                    Spacer()
                                                    Button("Save") { Task { await viewModel.save() } }
                                                        .appPrimaryButton()
                                                        .disabled(viewModel.isSaving)
                                                }

                                                VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                                                    Button("Cancel") { isEditMode = false }
                                                        .appSecondaryButton()
                                                    Button("Save") { Task { await viewModel.save() } }
                                                        .appPrimaryButton()
                                                        .disabled(viewModel.isSaving)
                                                }
                                            }
                                        }
                                        .appSection()
                                    }
                                }
                                .appForm(maxWidth: LayoutMetrics.formMaxWidth)
                            } else {
                                responsiveHeader {
                                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                                        Label("Health history overview", systemImage: "heart.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)

                                        HStack(spacing: AppDesignSystem.spacingSM) {
                                            infoPill("Record #\(history.id)")
                                            if let typeName = history.typeName, !typeName.isEmpty {
                                                infoPill(typeName)
                                            }
                                        }

                                        Text(history.date?.formatted(date: .long, time: .omitted) ?? "No date")
                                            .font(.title3)
                                            .fontWeight(.semibold)

                                        Text(history.description ?? "No description")
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                } actions: {
                                    HStack(spacing: AppDesignSystem.spacingSM) {
                                        Button("Edit", systemImage: "pencil") { isEditMode = true }
                                            .appEditButton()

                                        Button("Delete", systemImage: "trash", role: .destructive) { viewModel.showDeleteConfirmation = true }
                                            .appDeleteButton()
                                            .disabled(viewModel.isDeleting)
                                    }
                                }
                                .appCard(padding: AppDesignSystem.spacingLG)
                            }
                        }
                        .padding()
                        .frame(maxWidth: LayoutMetrics.readableContentMaxWidth, alignment: .leading)
                    }
                }
            } else {
                VStack(spacing: AppDesignSystem.spacingSM) {
                    Image(systemName: "heart.text.square")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Health history not found")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
