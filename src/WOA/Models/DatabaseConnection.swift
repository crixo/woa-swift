import Foundation

/// Represents the current status of the app's connection to its SQLite database.
struct DatabaseConnection: Codable, Equatable {

    enum Status: String, Codable {
        case notConfigured
        case connected
        case disconnected
    }

    var path: String
    var lastValidated: Date?
    var status: Status

    static let notConfigured = DatabaseConnection(path: "", lastValidated: nil, status: .notConfigured)
}
