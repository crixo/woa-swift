import SwiftUI

struct LastModifiedPatientsView: View {
    let patients: [PatientAuditSummary]
    let isLoading: Bool
    let errorMessage: String?
    let onOpenPatientDetails: (Int) -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
            Label("Last modified patients", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            if isLoading {
                ProgressView("Loading recent changes...")
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if patients.isEmpty {
                Text("No recent patient changes found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                    Text("Tap a patient to open their detail view")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(patients) { patient in
                        Button {
                            onOpenPatientDetails(patient.id)
                        } label: {
                            HStack(alignment: .center, spacing: AppDesignSystem.spacingSM) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(patient.fullName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(dateFormatter.string(from: patient.changedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Label("Open", systemImage: "chevron.right.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityHint("Opens the patient detail view")
                    }
                }
            }
        }
        .appPanel(padding: AppDesignSystem.spacingLG)
    }
}

#Preview("Recent patients") {
    LastModifiedPatientsView(
        patients: [
            PatientAuditSummary(id: 1, fullName: "Maria Rossi", changedAt: Date()),
            PatientAuditSummary(id: 2, fullName: "Luca Bianchi", changedAt: Date().addingTimeInterval(-86400))
        ],
        isLoading: false,
        errorMessage: nil,
        onOpenPatientDetails: { _ in }
    )
    .frame(width: 420)
}
