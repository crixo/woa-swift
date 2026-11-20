import Foundation

/// Persisted application configuration.
struct AppSettings: Codable, Equatable {

    enum AppConstants {
        static let lastModifiedPatientsLimit = 5
    }

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
    /// When `true`, the app requires a Google sign-in (checked via the default browser at every launch).
    /// Optional on purpose: settings files saved before this property existed have no such key,
    /// and a missing key decodes as `nil` (treated as `false`) instead of failing the whole decode.
    var googleAuthEnabled: Bool? = nil
    /// `true` = authenticate with the Google "iOS" OAuth client (no client secret, custom URL scheme redirect).
    /// `nil`/`false` = the "Desktop app" client (client secret, loopback redirect). Optional for the same reason as above.
    var googleAuthUseIOSClient: Bool? = nil

    static let `default` = AppSettings(
        databaseConnection: .notConfigured,
        logLevel: .info,
        theme: .system
    )
}