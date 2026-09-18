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
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 4) {
                ForEach(tables) { table in
                    Text("- \(table.name) (\(table.recordCount))")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Text("\(tables.count) tables found with \(totalRecords) total records")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let onContinue {
                Button("Continue") {
                    onContinue()
                }
                .keyboardShortcut(.defaultAction)
            }

            if let onReselectDatabase {
                Button("Re-select Database", role: .destructive) {
                    isShowingReselectConfirmation = true
                }
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
        .padding()
    }
}
