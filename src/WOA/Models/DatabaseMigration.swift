import Foundation

enum DatabaseMigrationResult: String, Codable {
    case success
    case failure
}

struct DatabaseMigration: Identifiable, Equatable {
    let id: String
    let name: String
    let timestamp: Date
    let result: DatabaseMigrationResult
    let errorMessage: String?
    var appliedInCurrentSession: Bool
}
