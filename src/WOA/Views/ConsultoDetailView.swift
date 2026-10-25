//
//  ConsultoPatientDetailView.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 20/09/2026.
//

import SwiftUI

struct ConsultoDetailView: View {
    let onOpenTreatment: (Int) -> Void
    let onAddTreatment: () -> Void
    let onOpenEvaluation: (Int) -> Void
    let onAddEvaluation: () -> Void
    let onOpenExam: (Int) -> Void
    let onAddExam: () -> Void
    let onDeleted: () -> Void
    var onEditConsulto: () -> Void = {}
    
    @StateObject private var viewModel: ConsultoDetailViewModel

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator, onOpenTreatment: @escaping (Int) -> Void, onAddTreatment: @escaping () -> Void, onOpenEvaluation: @escaping (Int) -> Void, onAddEvaluation: @escaping () -> Void, onOpenExam: @escaping (Int) -> Void, onAddExam: @escaping () -> Void, onDeleted: @escaping () -> Void, onEditConsulto: @escaping () -> Void) {
        self.onOpenTreatment = onOpenTreatment
        self.onAddTreatment = onAddTreatment
        self.onOpenEvaluation = onOpenEvaluation
        self.onAddEvaluation = onAddEvaluation
        self.onOpenExam = onOpenExam
        self.onAddExam = onAddExam
        self.onDeleted = onDeleted
        self.onEditConsulto = onEditConsulto
        _viewModel = StateObject(wrappedValue: ConsultoDetailViewModel(consultoID: consultoID, patientID: patientID, databaseFileURL: databaseFileURL, dataChangeCoordinator: dataChangeCoordinator))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.consultation == nil {
                ProgressView("Loading consultation...")
            } else if let consultation = viewModel.consultation {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
                        header(consultation)
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .appErrorText()
                                .padding(.horizontal, AppDesignSystem.spacingSM)
                        }
                        treatmentsSection
                        evaluationsSection
                        examsSection
                    }
                    .padding()
                    .frame(maxWidth: LayoutMetrics.readableContentMaxWidth, alignment: .leading)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                    Text("Consultation not found")
                }
            }
        }
        .navigationTitle("Scheda Consulto")
        .onAppear {
            Task { await viewModel.load() }
        }
        .confirmationDialog("Vuoi cancellare il consulto?", isPresented: $viewModel.showDeleteConfirmation, titleVisibility: .visible) {
            Button("Cancella il Consulto", role: .destructive) {
                Task {
                    if await viewModel.delete() { onDeleted() }
                }
            }
        } message: {
            Text("Questa azione cancella il consulto e i dati collegati.\nQuesta operazione e' irreversibile.")
        }
    }

    private func header(_ consultation: ConsultationDetail) -> some View {
        ResponsiveHeader {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                Label("Appointment overview", systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(consultation.initialProblem ?? "No problem recorded")
                    .font(.title2)
                    .fontWeight(.bold)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppDesignSystem.spacingSM) {
                    Text(consultation.date?.formatted(date: .long, time: .omitted) ?? "No date")
                    Text("•")
                    Text("ID \(consultation.id)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } actions: {
            HStack(spacing: AppDesignSystem.spacingSM) {
                Button {
                    //viewModel.beginEditing()
                    onEditConsulto()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .appEditButton()

                Button(role: .destructive) {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .appDeleteButton()
                .disabled(viewModel.isDeleting)
            }
            
        }
        .appCard(padding: AppDesignSystem.spacingLG)
    }

    @ViewBuilder
    private var treatmentsSection: some View {
        DisclosureGroup(isExpanded: $viewModel.isTreatmentsExpanded) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                if viewModel.treatments.isEmpty {
                    ContentUnavailableView("Nessun trattamento registrato", systemImage: "cross.case", description: Text("Add a treatment to keep the appointment record complete."))
                } else {
                    ForEach(viewModel.treatments) { treatment in
                        Button(action: { onOpenTreatment(treatment.id) }) {
                            HStack(spacing: AppDesignSystem.spacingMD) {
                                Image(systemName: "cross.case.fill")
                                    .foregroundStyle(.tint)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(treatment.date?.formatted(date: .abbreviated, time: .omitted) ?? "No date")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(treatment.description ?? "No description")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .appSection()
                    }
                }
                addRecordButton("Aggiungi Trattamento", systemImage: "cross.case.fill", action: onAddTreatment)
            }
            .padding(.top, AppDesignSystem.spacingSM)
        } label: {
            sectionLabel("Trattamenti", count: viewModel.treatments.count, systemImage: "cross.case.fill")
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }

    @ViewBuilder
    private var evaluationsSection: some View {
        DisclosureGroup(isExpanded: $viewModel.isEvaluationsExpanded) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                if viewModel.evaluations.isEmpty {
                    ContentUnavailableView("Nessuna Valutazione registrata", systemImage: "clipboard", description: Text("Aggiungi una Valutazione per questo consulto"))
                } else {
                    ForEach(viewModel.evaluations) { evaluation in
                        Button(action: { onOpenEvaluation(evaluation.id) }) {
                            HStack(spacing: AppDesignSystem.spacingMD) {
                                Image(systemName: "clipboard.fill")
                                    .foregroundStyle(.tint)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(evaluation.structural ?? "No structural notes")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    Text((evaluation.cranioSacral ?? "-") + " • " + (evaluation.akOrthodontic ?? "-"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .appSection()
                    }
                }
                addRecordButton("Aggiungi una Valutazione", systemImage: "clipboard.badge.plus", action: onAddEvaluation)
            }
            .padding(.top, AppDesignSystem.spacingSM)
        } label: {
            sectionLabel("Valutazioni", count: viewModel.evaluations.count, systemImage: "clipboard.fill")
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }

    @ViewBuilder
    private var examsSection: some View {
        DisclosureGroup(isExpanded: $viewModel.isExamsExpanded) {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                if viewModel.exams.isEmpty {
                    ContentUnavailableView("Nessun esame registrato", systemImage: "doc.text.magnifyingglass", description: Text("Aggiungi un nuovo esame per questo consulto"))
                } else {
                    ForEach(viewModel.exams) { exam in
                        Button(action: { onOpenExam(exam.id) }) {
                            HStack(spacing: AppDesignSystem.spacingMD) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundStyle(.tint)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(exam.date?.formatted(date: .abbreviated, time: .omitted) ?? "No date")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text((exam.typeName ?? "No type") + " • " + (exam.description ?? "No description"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .appSection()
                    }
                }
                addRecordButton("Aggiungi Esame", systemImage: "doc.badge.plus", action: onAddExam)
            }
            .padding(.top, AppDesignSystem.spacingSM)
        } label: {
            sectionLabel("Esami", count: viewModel.exams.count, systemImage: "doc.text.magnifyingglass")
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }

    private func sectionLabel(_ title: String, count: Int, systemImage: String) -> some View {
        HStack(spacing: AppDesignSystem.spacingSM) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.07), in: Capsule())
        }
    }

    private func addRecordButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(action: action) {
                Label(title, systemImage: systemImage)
            }
            .appAddButton()
        }
    }
}
