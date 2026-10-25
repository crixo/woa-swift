import Foundation

@MainActor
final class AppSettingsStore: ObservableObject {

    @Published private(set) var settings: AppSettings = .default
    @Published private(set) var settingsFilePath: String = "Unavailable"

    func load() {
        settings = ConfigurationService.load()

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
    }
}