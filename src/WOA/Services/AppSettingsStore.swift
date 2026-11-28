import Foundation

@MainActor
final class AppSettingsStore: ObservableObject {

    @Published private(set) var settings: AppSettings = .default
    @Published private(set) var settingsFilePath: String = "Unavailable"
    @Published private var themePreview: AppSettings.Theme?

    var appearanceTheme: AppSettings.Theme {
        themePreview ?? settings.theme
    }

    func load() {
        settings = ConfigurationService.load()
        themePreview = nil

        do {
            settingsFilePath = try ConfigurationService.configurationFileURL().path
        } catch {
            settingsFilePath = "Unavailable"
            AppLogger.error("❌ Failed to resolve settings file path: \(error.localizedDescription)")
        }
    }

    func save(_ settings: AppSettings) throws {
        try ConfigurationService.save(settings)
        self.settings = settings
        themePreview = nil
    }

    func previewTheme(_ theme: AppSettings.Theme) {
        themePreview = theme == settings.theme ? nil : theme
    }

    func discardThemePreview() {
        themePreview = nil
    }
}