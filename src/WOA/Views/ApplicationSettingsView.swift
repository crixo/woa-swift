import SwiftUI

/// Displays the persisted application settings without exposing storage logic to the view.
struct ApplicationSettingsView: View {

    let settings: AppSettings
    let settingsFilePath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Application Settings")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 4) {
                Text("Settings File")
                    .font(.headline)
                Text(settingsFilePath)
                    .font(.callout)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                settingRow(label: "Database Path", value: databasePath)
                settingRow(label: "Connection Status", value: settings.databaseConnection.status.rawValue)
                settingRow(label: "Last Validated", value: lastValidated)
                settingRow(label: "Log Level", value: settings.logLevel.rawValue)
                settingRow(label: "Theme", value: settings.theme.rawValue)
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
        LabeledContent(label) {
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}