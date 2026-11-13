import SwiftUI
import Sparkle

@main
struct WOA: App {

    private let sparkleDelegate: SparkleUpdaterDelegate
    private let updaterController: SPUStandardUpdaterController

    init() {
        // Ensure storage directories exist and the logger is ready before any view loads.
        _ = try? AppPaths.appSupportDirectory()
        AppLogger.info("Application launched")
        
        AppLogger.info("Initializing Sparkle updater")
        let delegate = SparkleUpdaterDelegate()
        self.sparkleDelegate = delegate
        
        // Starts Sparkle's automatic update checks (see SU* keys in Info.plist).
        updaterController = SPUStandardUpdaterController(
            // SUEnableAutomaticChecks = true in Info.plist tells it to check the appcast on its own: shortly after launch,
            // then every SUScheduledCheckInterval (86400 seconds, once a day).
            startingUpdater: true, //starts Sparkle’s updater as the app launches.
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        AppLogger.info("Sparkle updater initialized")
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

// MARK: - Sparkle logging

final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater,
                 didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
                 error: Error?) {
        guard let error else { return }

        AppLogger.error("Sparkle update cycle failed: \(error.localizedDescription)")
        // then the nested causes (skip the top-level error, it's already logged above)
        var current = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError
        while let e = current {
            AppLogger.error("  caused by \(e.domain) code=\(e.code): \(e.localizedDescription)")
            current = e.userInfo[NSUnderlyingErrorKey] as? NSError
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
        Button("Check for Updates…") {
            AppLogger.info("Sparkle manual update check requested")
            updater.checkForUpdates()
        }
        .disabled(!viewModel.canCheckForUpdates)
    }
}

// This is the view for our updater settings
// It manages local state for checking for updates and automatically downloading updates
// Upon user changes to these, the updater's properties are set. These are backed by NSUserDefaults.
// Note the updater properties should *only* be set when the user changes the state.
struct UpdaterSettingsView: View {
    private let updater: SPUUpdater
    
    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool
    
    init(updater: SPUUpdater) {
        self.updater = updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }
    
    var body: some View {
        VStack {
            Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                .onChange(of: automaticallyChecksForUpdates) {
                    updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
                }
            
            Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                .disabled(!automaticallyChecksForUpdates)
                .onChange(of: automaticallyDownloadsUpdates) { 
                    updater.automaticallyDownloadsUpdates = automaticallyChecksForUpdates
                }
        }.padding()
    }
}
