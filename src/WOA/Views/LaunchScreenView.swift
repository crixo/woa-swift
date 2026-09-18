import SwiftUI

/// Hosts the connected launch screen's table status and application settings panels.
struct LaunchScreenView: View {

    let tables: [TableInfo]
    let settings: AppSettings
    let settingsFilePath: String
    let onReselectDatabase: () -> Void

    private enum LayoutMetrics {
        static let panelSpacing: CGFloat = 24
        static let panelPadding: CGFloat = 20
        static let contentMaxWidth: CGFloat = 1_000
        static let wideLayoutMinimumWidth: CGFloat = 720
    }

    var body: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                wideLayout
                compactLayout
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: LayoutMetrics.panelSpacing) {
            tablePanel
                .frame(maxWidth: .infinity, alignment: .topLeading)

            Divider()

            settingsPanel
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: LayoutMetrics.wideLayoutMinimumWidth,
            maxWidth: LayoutMetrics.contentMaxWidth,
            alignment: .center
        )
        .padding(LayoutMetrics.panelPadding)
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.panelSpacing) {
            tablePanel
            Divider()
            settingsPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(LayoutMetrics.panelPadding)
    }

    private var tablePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Database Connection Status: Connected")
                .font(.headline)

            if let lastValidated = settings.databaseConnection.lastValidated {
                Text("Last validated: \(lastValidated.formatted())")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TableStatusView(
                tables: tables,
                onReselectDatabase: onReselectDatabase
            )
        }
    }

    private var settingsPanel: some View {
        ApplicationSettingsView(
            settings: settings,
            settingsFilePath: settingsFilePath
        )
    }
}