import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class DatabaseManagementViewModel: ObservableObject {

    let settingsStore: AppSettingsStore

    @Published var isLoading: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var tableStats: [TableInfo] = []
    @Published var connectionError: String?
    @Published var isSelecting: Bool = false
    @Published var selectedPath: String?
    @Published var validationError: String?
    @Published var isImporting: Bool = false
    @Published var importedTables: [TableInfo] = []
    @Published var didImportSuccessfully: Bool = false

    var isConfigured: Bool {
        settingsStore.settings.databaseConnection.status == .connected
            && !settingsStore.settings.databaseConnection.path.isEmpty
    }

    init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore
    }

    func loadSettings() {
        isLoading = true
        settingsStore.load()

        guard isConfigured else {
            connectionStatus = "Disconnected"
            tableStats = []
            isLoading = false
            return
        }

        Task {
            await testDatabaseConnection()
            await refreshTableStats()
            isLoading = false
        }
    }

    func testDatabaseConnection() async {
        let path = settingsStore.settings.databaseConnection.path
        guard !path.isEmpty else {
            connectionStatus = "Disconnected"
            return
        }

        do {
            try DatabaseValidator.validate(fileURL: URL(fileURLWithPath: path))
            connectionStatus = "Connected"
            connectionError = nil

            var settings = settingsStore.settings
            settings.databaseConnection.status = .connected
            settings.databaseConnection.lastValidated = Date()
            try? settingsStore.save(settings)
        } catch {
            connectionStatus = "Disconnected"
            connectionError = error.localizedDescription
            var settings = settingsStore.settings
            settings.databaseConnection.status = .disconnected
            try? settingsStore.save(settings)
            tableStats = []
            AppLogger.error("❌ \(error.localizedDescription)")
        }
    }

    func refreshTableStats() async {
        let path = settingsStore.settings.databaseConnection.path
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

    func resetConfiguration() {
        var settings = settingsStore.settings
        settings.databaseConnection = .notConfigured
        try? settingsStore.save(settings)
        connectionStatus = "Disconnected"
        connectionError = nil
        tableStats = []
    }

    func selectDatabase() {
        isSelecting = true
        defer { isSelecting = false }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = ["db", "sqlite", "sqlite3"].compactMap {
            UTType(filenameExtension: $0)
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectedPath = url.path
        validationError = nil
    }

    func importDatabase() {
        guard let selectedPath else { return }
        let sourceURL = URL(fileURLWithPath: selectedPath)

        isImporting = true
        validationError = nil
        connectionStatus = "Validating"

        Task {
            do {
                let destinationURL = try DatabaseInstaller.install(from: sourceURL)
                let tables = try TableRepository.fetchTableStats(fileURL: destinationURL)
                var settings = settingsStore.settings
                settings.databaseConnection = DatabaseConnection(
                    path: destinationURL.path,
                    lastValidated: Date(),
                    status: .connected
                )
                try settingsStore.save(settings)

                importedTables = tables
                connectionStatus = "Connected"
                didImportSuccessfully = true
                AppLogger.info("✅ Database import completed successfully: \(destinationURL.path)")
            } catch {
                AppLogger.error("❌ \(error.localizedDescription)")
                validationError = error.localizedDescription
                connectionStatus = "Disconnected"
            }
            isImporting = false
        }
    }

    func continueAfterImport() {
        didImportSuccessfully = false
        loadSettings()
    }
}