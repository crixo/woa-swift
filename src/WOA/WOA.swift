import SwiftUI
import Sparkle

@main
struct WOA: App {

    private let updaterController: SPUStandardUpdaterController

    init() {
        // Ensure storage directories exist and the logger is ready before any view loads.
        _ = try? AppPaths.appSupportDirectory()
        AppLogger.info("Application launched")

        // Starts Sparkle's automatic update checks (see SU* keys in Info.plist).
        updaterController = SPUStandardUpdaterController(
            // SUEnableAutomaticChecks = true in Info.plist tells it to check the appcast on its own: shortly after launch,
            // then every SUScheduledCheckInterval (86400 seconds, once a day).
            startingUpdater: true, //starts Sparkle’s updater as the app launches.
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}

// MARK: - Sparkle "Check for Updates…" menu item

/// Mirrors `SPUUpdater.canCheckForUpdates` so the menu item is disabled
/// while a check or an installation is already in progress.
private final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

private struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}
