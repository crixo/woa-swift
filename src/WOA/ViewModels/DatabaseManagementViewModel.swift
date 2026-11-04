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
    @Published var copySelectedDatabaseToApplicationSupport: Bool = false
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

    var canCopyActiveDatabaseToApplicationSupport: Bool {
        guard let activeDatabaseURL else { return false }
        return (try? isApplicationSupportDatabase(activeDatabaseURL)) == false
    }

    var canGrantDatabaseFolderAccess: Bool {
        canCopyActiveDatabaseToApplicationSupport
            && settingsStore.settings.databaseConnection.securityScopedDirectoryBookmark == nil
    }

    private let migrationService: DatabaseMigrationService
    private var selectedDatabaseURL: URL?
    private var selectedSecurityScopedURL: URL?
    private var selectedDatabaseDirectoryURL: URL?
    private var activeDatabaseURL: URL?
    private var activeSecurityScopedURL: URL?

    init(settingsStore: AppSettingsStore, migrationService: DatabaseMigrationService) {
        self.settingsStore = settingsStore
        self.migrationService = migrationService
    }

    func loadSettings() {
        isLoading = true
        settingsStore.load()

        guard hasConfiguredDatabase else {
            releaseActiveDatabaseAccess()
            connectionStatus = "Disconnected"
            tableStats = []
            isLoading = false
            return
        }

        do {
            let databaseURL = try resolveConfiguredDatabaseURL()
            Task {
                await connectConfiguredDatabase(at: databaseURL)
                isLoading = false
            }
        } catch {
            releaseActiveDatabaseAccess()
            connectionStatus = "Disconnected"
            connectionError = error.localizedDescription
            tableStats = []
            saveDisconnectedStatus()
            isLoading = false
        }
    }

    private func connectConfiguredDatabase(at databaseURL: URL) async {
        do {
            try await migrationService.applyPendingMigrations(to: databaseURL)
        } catch {
            await refreshSessionMigrations(for: databaseURL)
            migrationError = error.localizedDescription
            connectionStatus = "Disconnected"
            connectionError = error.localizedDescription
            tableStats = []
            saveDisconnectedStatus()
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
            saveDisconnectedStatus()
            tableStats = []
            AppLogger.error("❌ \(error.localizedDescription)")
        }
    }

    private func resolveConfiguredDatabaseURL() throws -> URL {
        let connection = settingsStore.settings.databaseConnection
        let configuredURL = URL(fileURLWithPath: connection.path).standardizedFileURL

        if let directoryBookmark = connection.securityScopedDirectoryBookmark {
            return try resolveDatabaseUsingDirectoryBookmark(
                directoryBookmark,
                configuredURL: configuredURL,
                connection: connection
            )
        }

        guard let bookmark = connection.securityScopedBookmark else {
            guard try isApplicationSupportDatabase(configuredURL) else {
                throw DatabaseAccessError.missingBookmark(configuredURL.path)
            }
            activeDatabaseURL = configuredURL
            return configuredURL
        }

        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ).standardizedFileURL

        guard resolvedURL.startAccessingSecurityScopedResource() else {
            throw DatabaseAccessError.accessDenied(resolvedURL.path)
        }

        let previousSecurityScopedURL = activeSecurityScopedURL
        if isStale || resolvedURL.path != connection.path {
            var settings = settingsStore.settings
            settings.databaseConnection.path = resolvedURL.path
            settings.databaseConnection.securityScopedBookmark = try makeSecurityScopedBookmark(for: resolvedURL)
            try settingsStore.save(settings)
        }
        activeSecurityScopedURL = resolvedURL
        activeDatabaseURL = resolvedURL
        if previousSecurityScopedURL != resolvedURL {
            previousSecurityScopedURL?.stopAccessingSecurityScopedResource()
        } else {
            resolvedURL.stopAccessingSecurityScopedResource()
        }
        return resolvedURL
    }

    private func resolveDatabaseUsingDirectoryBookmark(
        _ bookmark: Data,
        configuredURL: URL,
        connection: DatabaseConnection
    ) throws -> URL {
        var isStale = false
        let directoryURL = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ).standardizedFileURL
        guard directoryURL.startAccessingSecurityScopedResource() else {
            throw DatabaseAccessError.accessDenied(directoryURL.path)
        }

        do {
            let resourceValues = try directoryURL.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues.isDirectory == true else {
                throw DatabaseAccessError.bookmarkIsNotDirectory(directoryURL.path)
            }
            let databaseName = URL(fileURLWithPath: connection.path).lastPathComponent
            let databaseURL = directoryURL.appendingPathComponent(databaseName).standardizedFileURL
            let previousSecurityScopedURL = activeSecurityScopedURL

            if isStale || databaseURL.path != configuredURL.path {
                var settings = settingsStore.settings
                settings.databaseConnection.path = databaseURL.path
                settings.databaseConnection.securityScopedDirectoryBookmark = try makeSecurityScopedBookmark(for: directoryURL)
                try settingsStore.save(settings)
            }

            activeSecurityScopedURL = directoryURL
            activeDatabaseURL = databaseURL
            if previousSecurityScopedURL == directoryURL {
                directoryURL.stopAccessingSecurityScopedResource()
            } else {
                previousSecurityScopedURL?.stopAccessingSecurityScopedResource()
            }
            return databaseURL
        } catch {
            directoryURL.stopAccessingSecurityScopedResource()
            throw error
        }
    }

    private func makeSecurityScopedBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func isApplicationSupportDatabase(_ url: URL) throws -> Bool {
        let supportURL = try AppPaths.appSupportDirectory().standardizedFileURL
        return url.standardizedFileURL.pathComponents.starts(with: supportURL.pathComponents)
    }

    private func saveDisconnectedStatus() {
        var settings = settingsStore.settings
        settings.databaseConnection.status = .disconnected
        do {
            try settingsStore.save(settings)
        } catch {
            AppLogger.error("Unable to save disconnected database status: \(error.localizedDescription)")
        }
    }

    private func releaseActiveDatabaseAccess() {
        if let activeSecurityScopedURL {
            activeSecurityScopedURL.stopAccessingSecurityScopedResource()
        }
        activeSecurityScopedURL = nil
        activeDatabaseURL = nil
    }

    private func releaseSelectedDatabaseAccess() {
        if let selectedSecurityScopedURL {
            selectedSecurityScopedURL.stopAccessingSecurityScopedResource()
        }
        if let selectedDatabaseDirectoryURL {
            selectedDatabaseDirectoryURL.stopAccessingSecurityScopedResource()
        }
        selectedSecurityScopedURL = nil
        selectedDatabaseDirectoryURL = nil
        selectedDatabaseURL = nil
    }

    private func activateSelectedDatabase(_ databaseURL: URL, securityScopedDirectoryURL: URL?) {
        let previousSecurityScopedURL = activeSecurityScopedURL
        activeSecurityScopedURL = securityScopedDirectoryURL
        selectedDatabaseDirectoryURL = nil
        activeDatabaseURL = databaseURL
        previousSecurityScopedURL?.stopAccessingSecurityScopedResource()
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
        guard let databaseURL = activeDatabaseURL else {
            tableStats = []
            return
        }

        do {
            tableStats = try TableRepository.fetchTableStats(fileURL: databaseURL)
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
        releaseActiveDatabaseAccess()
        releaseSelectedDatabaseAccess()
        connectionStatus = "Disconnected"
        connectionError = nil
        migrationError = nil
        sessionMigrations = []
        migrationHistoryError = nil
        tableStats = []
        selectedPath = nil
        copySelectedDatabaseToApplicationSupport = false
        validationError = nil
    }

    func retryMigrations() {
        guard hasConfiguredDatabase else { return }
        migrationError = nil
        isLoading = true
        do {
            let databaseURL: URL
            if let activeDatabaseURL {
                databaseURL = activeDatabaseURL
            } else {
                databaseURL = try resolveConfiguredDatabaseURL()
            }
            Task {
                await connectConfiguredDatabase(at: databaseURL)
                isLoading = false
            }
        } catch {
            connectionError = error.localizedDescription
            connectionStatus = "Disconnected"
            isLoading = false
        }
    }

    func copyActiveDatabaseToApplicationSupportAndRetry() {
        guard let sourceURL = activeDatabaseURL, canCopyActiveDatabaseToApplicationSupport else { return }

        isLoading = true
        connectionError = nil
        migrationError = nil
        Task {
            do {
                let managedURL = try DatabaseInstaller.install(from: sourceURL)
                var settings = settingsStore.settings
                settings.databaseConnection.path = managedURL.path
                settings.databaseConnection.securityScopedBookmark = nil
                settings.databaseConnection.securityScopedDirectoryBookmark = nil
                settings.databaseConnection.status = .disconnected
                try settingsStore.save(settings)

                releaseActiveDatabaseAccess()
                activeDatabaseURL = managedURL
                await connectConfiguredDatabase(at: managedURL)
            } catch {
                migrationError = error.localizedDescription
                connectionError = error.localizedDescription
                connectionStatus = "Disconnected"
                AppLogger.error("Unable to copy the selected database into Application Support: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }

    func grantDatabaseFolderAccessAndRetry() {
        guard let databaseURL = activeDatabaseURL, canGrantDatabaseFolderAccess else { return }
        isLoading = true
        migrationError = nil
        connectionError = nil

        Task {
            do {
                guard let directoryURL = try requestDatabaseFolderAccess(for: databaseURL) else {
                    isLoading = false
                    return
                }
                selectedDatabaseDirectoryURL = directoryURL
                var settings = settingsStore.settings
                settings.databaseConnection.securityScopedBookmark = nil
                settings.databaseConnection.securityScopedDirectoryBookmark = try makeSecurityScopedBookmark(for: directoryURL)
                try settingsStore.save(settings)

                let previousSecurityScopedURL = activeSecurityScopedURL
                activeSecurityScopedURL = directoryURL
                selectedDatabaseDirectoryURL = nil
                previousSecurityScopedURL?.stopAccessingSecurityScopedResource()
                await connectConfiguredDatabase(at: databaseURL)
            } catch {
                releaseSelectedDatabaseAccess()
                migrationError = error.localizedDescription
                connectionError = error.localizedDescription
                connectionStatus = "Disconnected"
                AppLogger.error("Unable to grant database folder access: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }

    private func requestDatabaseFolderAccess(for databaseURL: URL) throws -> URL? {
        let containingDirectory = databaseURL.deletingLastPathComponent().standardizedFileURL
        let panel = NSOpenPanel()
        panel.title = "Allow Access to the Database Folder"
        panel.message = "Select the folder containing \(databaseURL.lastPathComponent). WOA needs folder access so SQLite can manage the database and its journal files."
        panel.prompt = "Allow Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = containingDirectory

        guard panel.runModal() == .OK, let selectedDirectory = panel.url?.standardizedFileURL else {
            return nil
        }
        guard selectedDirectory == containingDirectory else {
            throw DatabaseAccessError.wrongDirectory(
                expected: containingDirectory.path,
                selected: selectedDirectory.path
            )
        }
        guard selectedDirectory.startAccessingSecurityScopedResource() else {
            throw DatabaseAccessError.accessDenied(selectedDirectory.path)
        }
        return selectedDirectory
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
        let standardizedURL = url.standardizedFileURL
        do {
            let isInternal = try isApplicationSupportDatabase(standardizedURL)
            if !isInternal {
                guard standardizedURL.startAccessingSecurityScopedResource() else {
                    throw DatabaseAccessError.accessDenied(standardizedURL.path)
                }
            }
            releaseSelectedDatabaseAccess()
            selectedSecurityScopedURL = isInternal ? nil : standardizedURL
            selectedDatabaseURL = standardizedURL
            selectedPath = standardizedURL.path
            validationError = nil
            connectionError = nil
        } catch {
            releaseSelectedDatabaseAccess()
            selectedPath = nil
            validationError = error.localizedDescription
            connectionError = nil
            AppLogger.error("Unable to access selected database: \(error.localizedDescription)")
        }
    }

    func importDatabase() {
        guard let sourceURL = selectedDatabaseURL else { return }

        isImporting = true
        validationError = nil
        connectionError = nil
        connectionStatus = "Validating"

        Task {
            do {
                // Run heavy I/O operations on a background thread
                let (destinationURL, isExternal): (URL, Bool) = try await Task.detached(priority: .userInitiated) {
                    let dest: URL
                    let external: Bool
                    if self.copySelectedDatabaseToApplicationSupport {
                        dest = try DatabaseInstaller.install(from: sourceURL)
                        external = false
                    } else {
                        dest = sourceURL
                        external = try !self.isApplicationSupportDatabase(sourceURL)
                    }
                    return (dest, external)
                }.value

                let directoryBookmark: Data?
                let authorizedDirectoryURL: URL?
                if isExternal, let selectedDatabaseURL {
                    guard let folderURL = try requestDatabaseFolderAccess(for: selectedDatabaseURL) else {
                        isImporting = false
                        return
                    }
                    selectedDatabaseDirectoryURL = folderURL
                    directoryBookmark = try makeSecurityScopedBookmark(for: folderURL)
                    authorizedDirectoryURL = folderURL
                } else {
                    directoryBookmark = nil
                    authorizedDirectoryURL = nil
                }

                var settings = settingsStore.settings
                settings.databaseConnection = DatabaseConnection(
                    path: destinationURL.path,
                    securityScopedDirectoryBookmark: directoryBookmark,
                    status: .disconnected
                )
                try settingsStore.save(settings)
                activateSelectedDatabase(destinationURL, securityScopedDirectoryURL: authorizedDirectoryURL)

                do {
                    try await migrationService.applyPendingMigrations(to: destinationURL)
                } catch {
                    await refreshSessionMigrations(for: destinationURL)
                    migrationError = error.localizedDescription
                    connectionStatus = "Disconnected"
                    connectionError = error.localizedDescription
                    validationError = error.localizedDescription
                    tableStats = []
                    isImporting = false
                    AppLogger.error("Database import blocked by migration failure: \(error.localizedDescription)")
                    return
                }

                await refreshSessionMigrations(for: destinationURL)
                
                // Run validation and stats fetching on background thread
                let tables = try await Task.detached(priority: .userInitiated) {
                    try DatabaseValidator.validate(fileURL: destinationURL)
                    return try TableRepository.fetchTableStats(fileURL: destinationURL)
                }.value
                
                settings.databaseConnection.lastValidated = Date()
                settings.databaseConnection.status = .connected
                try settingsStore.save(settings)
                importedTables = tables
                connectionStatus = "Connected"
                migrationError = nil
                connectionError = nil
                didImportSuccessfully = true
                AppLogger.info("✅ Database selection completed successfully: \(destinationURL.path)")
            } catch {
                AppLogger.error("❌ \(error.localizedDescription)")
                validationError = error.localizedDescription
                connectionError = error.localizedDescription
                connectionStatus = "Disconnected"
            }
            releaseSelectedDatabaseAccess()
            isImporting = false
        }
    }

    func continueAfterImport() {
        didImportSuccessfully = false
        loadSettings()
    }

    deinit {
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
        selectedSecurityScopedURL?.stopAccessingSecurityScopedResource()
        selectedDatabaseDirectoryURL?.stopAccessingSecurityScopedResource()
    }
}

private enum DatabaseAccessError: LocalizedError {
    case missingBookmark(String)
    case accessDenied(String)
    case bookmarkIsNotDirectory(String)
    case wrongDirectory(expected: String, selected: String)

    var errorDescription: String? {
        switch self {
        case .missingBookmark(let path):
            return "WOA cannot restore permission to access the selected database at \(path). Reselect the database file."
        case .accessDenied(let path):
            return "WOA was unable to obtain permission to access the selected database at \(path)."
        case .bookmarkIsNotDirectory(let path):
            return "The saved database permission does not refer to a folder: \(path). Grant access to the folder containing the database."
        case .wrongDirectory(let expected, let selected):
            return "Select the folder that contains the database. Expected \(expected), but selected \(selected)."
        }
    }
}