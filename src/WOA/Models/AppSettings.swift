import Foundation

/// Persisted application configuration.
struct AppSettings: Codable, Equatable {

    enum LogLevel: String, Codable {
        case info
        case warning
        case error
    }

    enum Theme: String, Codable {
        case system
        case light
        case dark
    }

    var databaseConnection: DatabaseConnection
    var logLevel: LogLevel
    var theme: Theme

    static let `default` = AppSettings(
        databaseConnection: .notConfigured,
        logLevel: .info,
        theme: .system
    )
}
