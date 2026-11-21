import SwiftUI

/// Dedicated inline destination for editable preferences and read-only system information.
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let onCancel: () -> Void
    let onSaved: () -> Void

    private enum LayoutMetrics {
        static let contentWidth: CGFloat = 760
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXL) {
                editableSettingsSection
                systemSettingsSection
                actionBar
            }
            .frame(maxWidth: LayoutMetrics.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(AppDesignSystem.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Impostazioni")
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
            FormActionBar(
                title: "Salva",
                systemImage: nil,
                submissionStyle: .save,
                isLoading: false,
                onCancel: onCancel,
                onSubmit: {
                    if viewModel.save() {
                        onSaved()
                    }
                }
            )
        }
        .appCard(padding: AppDesignSystem.spacingLG)
    }

    private var editableSettingsSection: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
            Label("Impostazioni modificabili", systemImage: "slider.horizontal.3")
                .font(.title3.weight(.semibold))

            Form {
                Section {
                    Picker("Tema", selection: $viewModel.draft.theme) {
                        Text("Sistema").tag(AppSettings.Theme.system)
                        Text("Chiaro").tag(AppSettings.Theme.light)
                        Text("Scuro").tag(AppSettings.Theme.dark)
                    }

                    Picker("Livello log", selection: $viewModel.draft.logLevel) {
                        Text("Info").tag(AppSettings.LogLevel.info)
                        Text("Avviso").tag(AppSettings.LogLevel.warning)
                        Text("Errore").tag(AppSettings.LogLevel.error)
                    }

                    Toggle("Richiedi autenticazione Google", isOn: $viewModel.googleAuthEnabled)

                    Picker("Client Google", selection: $viewModel.googleAuthUseIOSClient) {
                        Text("Desktop app").tag(false)
                        Text("Client iOS").tag(true)
                    }
                }

                Section("Pazienti modificati di recente") {
                    TextField(
                        "Numero di pazienti",
                        text: $viewModel.lastModifiedPatientsLimitText
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180, alignment: .leading)

                    Text("Deve essere un numero intero positivo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let validationMessage = viewModel.validationMessage {
                        Text(validationMessage)
                            .appErrorText()
                    }
                }
            }
            .formStyle(.grouped)

            if let saveErrorMessage = viewModel.saveErrorMessage {
                Text(saveErrorMessage)
                    .appErrorText()
            }
        }
        .appCard(padding: AppDesignSystem.spacingLG)
    }

    private var systemSettingsSection: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.spacingMD) {
            Label("Impostazioni di sistema", systemImage: "lock.fill")
                .font(.title3.weight(.semibold))

            Text("Valori di sola lettura forniti dall'applicazione e dal database attivo.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: AppDesignSystem.spacingXS) {
                settingRow(label: "File impostazioni", value: viewModel.settingsFilePath)
                settingRow(label: "Percorso database", value: databasePath)
                settingRow(label: "Stato connessione", value: viewModel.draft.databaseConnection.status.rawValue)
                settingRow(
                    label: "Ultima validazione",
                    value: viewModel.draft.databaseConnection.lastValidated?.formatted() ?? "Non disponibile"
                )
                settingRow(label: "Versione applicazione", value: appVersionLabel)
            }
        }
        .appCard(padding: AppDesignSystem.spacingLG)
    }

    private var databasePath: String {
        viewModel.draft.databaseConnection.path.isEmpty
            ? "Non configurato"
            : viewModel.draft.databaseConnection.path
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        #if DEBUG
        return "v\(version) (next)"
        #else
        return "v\(version)"
        #endif
    }

    private func settingRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: AppDesignSystem.spacingMD)
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, AppDesignSystem.spacingSM)
        .background(
            Color.primary.opacity(0.02),
            in: RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous)
        )
    }
}
