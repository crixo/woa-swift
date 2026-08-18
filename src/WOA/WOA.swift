import SwiftUI

@main
struct WOA: App {

    init() {
        // Ensure storage directories exist and the logger is ready before any view loads.
        _ = try? AppPaths.appSupportDirectory()
        AppLogger.info("Application launched")
    }

    var body: some Scene {
        WindowGroup {
            SettingsView()
        }
    }
}
