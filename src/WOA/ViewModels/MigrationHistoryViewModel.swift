import Foundation

@MainActor
final class MigrationHistoryViewModel: ObservableObject {

    @Published private(set) var migrations: [DatabaseMigration] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let databaseURL: URL
    private let migrationService: DatabaseMigrationService

    init(databaseURL: URL, migrationService: DatabaseMigrationService) {
        self.databaseURL = databaseURL
        self.migrationService = migrationService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            migrations = try await migrationService.migrationHistory(for: databaseURL)
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Unable to load migration history: \(error.localizedDescription)")
        }
    }
}
