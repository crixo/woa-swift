import SwiftUI

/// Displays the persisted application settings without exposing storage logic to the view.
struct SettingsWidgetView: View {

    let settings: AppSettings
    let settingsFilePath: String
    let onOpenSettings: () -> Void

    init(
        settings: AppSettings,
        settingsFilePath: String,
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self.settingsFilePath = settingsFilePath
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingLG) {
            Label("Impostazioni applicazione", systemImage: "gearshape.fill")
                .homeWidgetTitle()

            VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                    Text("File impostazioni")
                        .font(.subheadline.weight(.semibold))
                    Text(settingsFilePath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .appSection()

                VStack(alignment: .leading, spacing: AppDesignSystem.spacingSM) {
                    settingRow(label: "Percorso database", value: databasePath)
                    settingRow(label: "Stato connessione", value: settings.databaseConnection.status.rawValue)
                    settingRow(label: "Ultima validazione", value: lastValidated)
                    settingRow(label: "Livello log", value: settings.logLevel.rawValue)
                    settingRow(label: "Tema", value: settings.theme.rawValue)
                    settingRow(label: "Autenticazione con Google", value: settings.googleAuthEnabled.toString())
                    settingRow(label: "Autenticazione con IOS Client", value: settings.googleAuthUseIOSClient.toString())
                }
            }

            Button {
                onOpenSettings()
            } label: {
                Label("Impostazioni", systemImage: "slider.horizontal.3")
            }
            .appSecondaryButton()
            .frame(maxWidth: .infinity, alignment: .leading)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var databasePath: String {
        settings.databaseConnection.path.isEmpty
            ? "Non configurato"
            : settings.databaseConnection.path
    }

    private var lastValidated: String {
        settings.databaseConnection.lastValidated?.formatted() ?? "Non disponibile"
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

#Preview {
    SettingsWidgetView(
        settings: .default,
        settingsFilePath: "Preview configuration"
    )
}
