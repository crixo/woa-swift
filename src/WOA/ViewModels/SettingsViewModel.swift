import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var draft: AppSettings
    @Published var lastModifiedPatientsLimitText: String
    @Published var googleAuthEnabled: Bool
    @Published var googleAuthUseIOSClient: Bool
    @Published var validationMessage: String?
    @Published var saveErrorMessage: String?

    let settingsFilePath: String

    private let settingsStore: AppSettingsStore

    init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore
        draft = settingsStore.settings
        settingsFilePath = settingsStore.settingsFilePath
        googleAuthEnabled = settingsStore.settings.googleAuthEnabled ?? false
        googleAuthUseIOSClient = settingsStore.settings.googleAuthUseIOSClient ?? false
        lastModifiedPatientsLimitText = String(settingsStore.settings.effectiveLastModifiedPatientsLimit)
    }

    func previewThemeChange() {
        settingsStore.previewTheme(draft.theme)
    }

    func discardThemePreview() {
        settingsStore.discardThemePreview()
    }

    func resetDraft() {
        draft = settingsStore.settings
        googleAuthEnabled = settingsStore.settings.googleAuthEnabled ?? false
        googleAuthUseIOSClient = settingsStore.settings.googleAuthUseIOSClient ?? false
        lastModifiedPatientsLimitText = String(settingsStore.settings.effectiveLastModifiedPatientsLimit)
        validationMessage = nil
        saveErrorMessage = nil
    }

    func save() -> Bool {
        validationMessage = nil
        saveErrorMessage = nil

        let trimmedText = lastModifiedPatientsLimitText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let limit = Int(trimmedText), limit > 0 else {
            validationMessage = "Inserisci un numero intero positivo."
            return false
        }

        draft.googleAuthEnabled = googleAuthEnabled
        draft.googleAuthUseIOSClient = googleAuthUseIOSClient
        draft.lastModifiedPatientsLimit = limit

        do {
            try settingsStore.save(draft)
            return true
        } catch {
            saveErrorMessage = "Impossibile salvare le impostazioni: \(error.localizedDescription)"
            AppLogger.error("❌ Unable to save application settings: \(error.localizedDescription)")
            return false
        }
    }
}
