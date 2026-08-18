import Foundation

/// Loads and persists `AppSettings` as JSON in Application Support.
enum ConfigurationService {

    /// Loads the persisted settings, returning `.default` if no configuration file exists yet.
    static func load() -> AppSettings {
        do {
            let url = try AppPaths.configurationFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .default
            }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            AppLogger.error("❌ Failed to load configuration: \(error.localizedDescription)")
            return .default
        }
    }

    /// Persists `settings` to the configuration file, overwriting any existing content.
    static func save(_ settings: AppSettings) throws {
        let url = try AppPaths.configurationFileURL()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: url, options: .atomic)
    }
}
