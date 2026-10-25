import SwiftUI

/// Hosts the connected launch screen's table status and application settings panels.
struct LaunchScreenView: View {

    let tables: [TableInfo]
    let sessionMigrations: [DatabaseMigration]
    let migrationHistoryError: String?
    let settings: AppSettings
    let settingsFilePath: String
    let onMigrationHistory: () -> Void
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
        VStack(spacing: LayoutMetrics.panelSpacing) {
            HStack(alignment: .top, spacing: LayoutMetrics.panelSpacing) {
                VStack(alignment: .leading, spacing: LayoutMetrics.panelSpacing) {
                    tablePanel
                    migrationsPanel
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                settingsPanel
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: LayoutMetrics.wideLayoutMinimumWidth)
        }
        .frame(maxWidth: LayoutMetrics.contentMaxWidth, alignment: .center)
        .padding(LayoutMetrics.panelPadding)
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.panelSpacing) {
            tablePanel
            migrationsPanel
            settingsPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(LayoutMetrics.panelPadding)
    }

    private var tablePanel: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
            Label("Database connection", systemImage: "network")
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
            .appCard(padding: AppDesignSystem.spacingLG)
        }
    }

    private var settingsPanel: some View {
        ApplicationSettingsView(
            settings: settings,
            settingsFilePath: settingsFilePath
        )
        .appCard(padding: AppDesignSystem.spacingLG)
    }

    private var migrationsPanel: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
            HStack {
                Label("Migrations applied this session", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                Button("Migration History", systemImage: "list.bullet") {
                    onMigrationHistory()
                }
                .appSecondaryButton()
            }

            Group {
                if let migrationHistoryError {
                    Text("Unable to load migration history: \(migrationHistoryError)")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                } else if sessionMigrations.isEmpty {
                    Text("No migrations applied")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                            ForEach(sessionMigrations) { migration in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(migration.name)
                                        .font(.callout.weight(.medium))
                                        .textSelection(.enabled)
                                    Spacer(minLength: AppDesignSystem.spacingSM)
                                    Text(migration.timestamp, format: .dateTime.year().month().day().hour().minute().second())
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(height: min(CGFloat(sessionMigrations.count) * 32, 96))
                    .accessibilityLabel("Migrations applied this session")
                }
            }

            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard(padding: AppDesignSystem.spacingLG)
        }
    }
}