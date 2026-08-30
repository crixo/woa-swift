import Foundation
import AppKit

/// Drives the first-run database selection and import workflow.
@MainActor
final class DatabaseSelectorViewModel: ObservableObject {

    @Published var isSelecting: Bool = false
    @Published var selectedPath: String?
    @Published var validationError: String?
    @Published var isImporting: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var importedTables: [TableInfo] = []
    @Published var didImportSuccessfully: Bool = false

    /// Presents an NSOpenPanel filtered to SQLite database files.
    func selectDatabase() {
        isSelecting = true
        defer { isSelecting = false }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = []
        panel.allowedFileTypes = ["db", "sqlite", "sqlite3"]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectedPath = url.path
        validationError = nil
    }

    /// Validates and copies the selected database into Application Support.
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

                var settings = ConfigurationService.load()
                settings.databaseConnection = DatabaseConnection(
                    path: destinationURL.path,
                    lastValidated: Date(),
                    status: .connected
                )
                try ConfigurationService.save(settings)

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
}
