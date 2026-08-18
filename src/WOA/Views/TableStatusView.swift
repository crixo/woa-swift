import SwiftUI

/// One-time confirmation screen shown after a successful database import.
struct TableStatusView: View {

    let tables: [TableInfo]
    let onContinue: () -> Void

    private var totalRecords: Int {
        tables.reduce(0) { $0 + $1.recordCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Database Import Successful")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 4) {
                ForEach(tables) { table in
                    Text("- \(table.name) (\(table.recordCount))")
                        .font(.body)
                }
            }

            Text("\(tables.count) tables found with \(totalRecords) total records")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Continue") {
                onContinue()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
}
