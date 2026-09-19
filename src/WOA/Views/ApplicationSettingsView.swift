import SwiftUI

/// Displays the persisted application settings without exposing storage logic to the view.
struct ApplicationSettingsView: View {

    let settings: AppSettings
    let settingsFilePath: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
            Label("Application settings", systemImage: "gearshape.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                    Text("Settings file")
                        .font(.subheadline.weight(.semibold))
                    Text(settingsFilePath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .appSection()

                VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                    settingRow(label: "Database Path", value: databasePath)
                    settingRow(label: "Connection Status", value: settings.databaseConnection.status.rawValue)
                    settingRow(label: "Last Validated", value: lastValidated)
                    settingRow(label: "Log Level", value: settings.logLevel.rawValue)
                    settingRow(label: "Theme", value: settings.theme.rawValue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var databasePath: String {
        settings.databaseConnection.path.isEmpty
            ? "Not configured"
            : settings.databaseConnection.path
    }

    private var lastValidated: String {
        settings.databaseConnection.lastValidated?.formatted() ?? "Not available"
    }

    private func settingRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, AppDesignSystem.spacingSM)
        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
    }
}