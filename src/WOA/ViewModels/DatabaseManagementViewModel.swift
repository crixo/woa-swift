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
    @Published var migrationError: String?
    @Published private(set) var sessionMigrations: [DatabaseMigration] = []
    @Published private(set) var migrationHistoryError: String?
    @Published var isSelecting: Bool = false
    @Published var selectedPath: String?
    @Published var validationError: String?
    @Published var isImporting: Bool = false
    @Published var importedTables: [TableInfo] = []
    @Published var didImportSuccessfully: Bool = false

    var isConfigured: Bool {
        settingsStore.settings.databaseConnection.status == .connected
            && hasConfiguredDatabase
    }

    var hasConfiguredDatabase: Bool {
        !settingsStore.settings.databaseConnection.path.isEmpty
    }

    var isReadyForUse: Bool {
        isConfigured && !isLoading && migrationError == nil
    }

    private let migrationService: DatabaseMigrationService

    init(settingsStore: AppSettingsStore, migrationService: DatabaseMigrationService) {
        self.settingsStore = settingsStore
        self.migrationService = migrationService
    }

    func loadSettings() {
        isLoading = true
        settingsStore.load()

        guard hasConfiguredDatabase else {
            connectionStatus = "Disconnected"
            tableStats = []
            isLoading = false
            return
        }

        Task {
            await connectConfiguredDatabase()
            isLoading = false
        }
    }

    private func connectConfiguredDatabase() async {
        let path = settingsStore.settings.databaseConnection.path
        guard !path.isEmpty else {
            connectionStatus = "Disconnected"
            return
        }

        let databaseURL = URL(fileURLWithPath: path)
        do {
            try await migrationService.applyPendingMigrations(to: databaseURL)
        } catch {
            await refreshSessionMigrations(for: databaseURL)
            migrationError = error.localizedDescription
            connectionStatus = "Disconnected"
            connectionError = error.localizedDescription
            tableStats = []
            var settings = settingsStore.settings
            settings.databaseConnection.status = .disconnected
            do {
                try settingsStore.save(settings)
            } catch {
                AppLogger.error("Unable to save disconnected database status: \(error.localizedDescription)")
            }
            AppLogger.error("Database migrations blocked startup: \(error.localizedDescription)")
            return
        }

        await refreshSessionMigrations(for: databaseURL)
        migrationError = nil
        do {
            try DatabaseValidator.validate(fileURL: databaseURL)
            connectionStatus = "Connected"
            connectionError = nil

            var settings = settingsStore.settings
            settings.databaseConnection.status = .connected
            settings.databaseConnection.lastValidated = Date()
            try settingsStore.save(settings)
            await refreshTableStats()
        } catch {
            connectionStatus = "Disconnected"
            connectionError = error.localizedDescription
            var settings = settingsStore.settings
            settings.databaseConnection.status = .disconnected
            do {
                try settingsStore.save(settings)
            } catch {
                AppLogger.error("Unable to save disconnected database status: \(error.localizedDescription)")
            }
            tableStats = []
            AppLogger.error("❌ \(error.localizedDescription)")
        }
    }

    private func refreshSessionMigrations(for databaseURL: URL) async {
        do {
            sessionMigrations = try await migrationService.migrationHistory(for: databaseURL)
                .filter { $0.appliedInCurrentSession && $0.result == .success }
            migrationHistoryError = nil
        } catch {
            migrationHistoryError = error.localizedDescription
            AppLogger.error("Unable to load current-session migrations: \(error.localizedDescription)")
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
        do {
            try settingsStore.save(settings)
        } catch {
            connectionError = "Unable to reset database configuration: \(error.localizedDescription)"
            AppLogger.error(connectionError ?? "Unable to reset database configuration.")
            return
        }
        connectionStatus = "Disconnected"
        connectionError = nil
        migrationError = nil
        sessionMigrations = []
        migrationHistoryError = nil
        tableStats = []
    }

    func retryMigrations() {
        guard hasConfiguredDatabase else { return }
        migrationError = nil
        isLoading = true
        Task {
            await connectConfiguredDatabase()
            isLoading = false
        }
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

                var settings = settingsStore.settings
                settings.databaseConnection = DatabaseConnection(
                    path: destinationURL.path,
                    status: .disconnected
                )
                try settingsStore.save(settings)

                do {
                    try await migrationService.applyPendingMigrations(to: destinationURL)
                } catch {
                    await refreshSessionMigrations(for: destinationURL)
                    migrationError = error.localizedDescription
                    connectionStatus = "Disconnected"
                    validationError = error.localizedDescription
                    tableStats = []
                    isImporting = false
                    AppLogger.error("Database import blocked by migration failure: \(error.localizedDescription)")
                    return
                }

                await refreshSessionMigrations(for: destinationURL)
                try DatabaseValidator.validate(fileURL: destinationURL)
                let tables = try TableRepository.fetchTableStats(fileURL: destinationURL)
                settings.databaseConnection.lastValidated = Date()
                settings.databaseConnection.status = .connected
                try settingsStore.save(settings)
                importedTables = tables
                connectionStatus = "Connected"
                migrationError = nil
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