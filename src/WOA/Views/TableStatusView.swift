import SwiftUI

/// One-time confirmation screen shown after a successful database import.
struct TableStatusView: View {

    let tables: [TableInfo]
    private let title: String
    private let onContinue: (() -> Void)?
    private let onReselectDatabase: (() -> Void)?
    @State private var isShowingReselectConfirmation = false

    init(tables: [TableInfo], onContinue: @escaping () -> Void) {
        self.tables = tables
        self.title = "Database Import Successful"
        self.onContinue = onContinue
        self.onReselectDatabase = nil
    }

    init(tables: [TableInfo], onReselectDatabase: @escaping () -> Void) {
        self.tables = tables
        self.title = "Database Tables"
        self.onContinue = nil
        self.onReselectDatabase = onReselectDatabase
    }

    private var totalRecords: Int {
        tables.reduce(0) { $0 + $1.recordCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
            HStack(alignment: .center) {
                Label(title, systemImage: "checkmark.shield.fill")
                    .font(.title2.weight(.semibold))
                Spacer()
                if let onContinue {
                    Button("Continue") {
                        onContinue()
                    }
                    .appPrimaryButton()
                    .keyboardShortcut(.defaultAction)
                }
            }

            if tables.isEmpty {
                VStack(spacing: AppDesignSystem.spacingSM) {
                    Image(systemName: "tablecells.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No tables available")
                        .font(.headline)
                    Text("The selected database does not expose any readable tables.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                    ForEach(tables) { table in
                        HStack(alignment: .center) {
                            Label(table.name, systemImage: "tablecells")
                                .font(.body)
                            Spacer()
                            Text("\(table.recordCount) rows")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, AppDesignSystem.spacingSM)
                        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
                    }
                }
            }

            Text("\(tables.count) tables found with \(totalRecords) total records")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let onReselectDatabase {
                Button("Re-select Database", role: .destructive) {
                    isShowingReselectConfirmation = true
                }
                .appSecondaryButton()
                .confirmationDialog(
                    "Re-select Database?",
                    isPresented: $isShowingReselectConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Re-select Database", role: .destructive) {
                        onReselectDatabase()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The current database connection will be cleared.")
                }
            }
        }
    }
}
