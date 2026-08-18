import Foundation

/// Drives the settings screen: database connection status and table statistics.
@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var isConfigured: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var tableStats: [TableInfo] = []
    @Published var allSettings: AppSettings = .default
    @Published var isLoading: Bool = false
    @Published var connectionError: String?

    /// Loads persisted settings and, if a database is configured, refreshes its stats.
    func loadSettings() {
        isLoading = true
        allSettings = ConfigurationService.load()
        isConfigured = allSettings.databaseConnection.status == .connected
            && !allSettings.databaseConnection.path.isEmpty

        if isConfigured {
            Task {
                await testDatabaseConnection()
                await refreshTableStats()
                isLoading = false
            }
        } else {
            connectionStatus = "Disconnected"
            isLoading = false
        }
    }

    /// Validates that the configured database file is still reachable and well-formed.
    func testDatabaseConnection() async {
        let path = allSettings.databaseConnection.path
        guard !path.isEmpty else {
            connectionStatus = "Disconnected"
            return
        }
        let url = URL(fileURLWithPath: path)
        do {
            try DatabaseValidator.validate(fileURL: url)
            connectionStatus = "Connected"
            connectionError = nil

            var settings = allSettings
            settings.databaseConnection.status = .connected
            settings.databaseConnection.lastValidated = Date()
            allSettings = settings
            try? ConfigurationService.save(settings)
        } catch {
            connectionStatus = "Disconnected"
            connectionError = error.localizedDescription
            AppLogger.error("❌ \(error.localizedDescription)")
        }
    }

    /// Refreshes the table list with current record counts.
    func refreshTableStats() async {
        let path = allSettings.databaseConnection.path
        guard !path.isEmpty else {
            tableStats = []
            return
        }
        do {
            tableStats = try TableRepository.fetchTableStats(fileURL: URL(fileURLWithPath: path))
        } catch {
            AppLogger.error("❌ \(error.localizedDescription)")
            tableStats = []
        }
    }

    /// Clears the current database configuration so the user can select a new file.
    func resetConfiguration() {
        var settings = allSettings
        settings.databaseConnection = .notConfigured
        allSettings = settings
        try? ConfigurationService.save(settings)
        isConfigured = false
        connectionStatus = "Disconnected"
        tableStats = []
    }
}
