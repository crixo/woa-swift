import SwiftUI
import Sparkle

@main
struct WOA: App {

    private let sparkleDelegate: SparkleUpdaterDelegate
    private let updaterController: SPUStandardUpdaterController
    @StateObject private var settingsStore: AppSettingsStore
    @StateObject private var auth = GoogleAuthService()

    init() {
        let appSettingsStore = AppSettingsStore()
        appSettingsStore.load()
        _settingsStore = StateObject(wrappedValue: appSettingsStore)
        
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
            
            AuthGate(
                isEnabled: settingsStore.settings.googleAuthEnabled ?? false,
                clientType: (settingsStore.settings.googleAuthUseIOSClient ?? false) ? .ios : .desktop
            ) {
                MainView(settingsStore: settingsStore)
            }
            .environmentObject(auth)
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

    private static let noUpdateAvailableCode = 1001

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        guard let error else {
            AppLogger.info("Sparkle update cycle completed successfully")
            return
        }
        
        let info = Bundle.main.infoDictionary
        AppLogger.info("Build: \(info?["CFBundleVersion"] ?? "?"), Version: \(info?["CFBundleShortVersionString"] ?? "?")")


        let nsError = error as NSError

//        AppLogger.debug("""
//            Sparkle:
//            domain=\(nsError.domain)
//            code=\(nsError.code)
//            description=\(nsError.localizedDescription)
//            """)

        if nsError.domain == SUSparkleErrorDomain,
           nsError.code == Self.noUpdateAvailableCode {
            AppLogger.info("Sparkle update check completed: app is already up to date")
            return
        }
        
        AppLogger.error("Sparkle update cycle failed: \(error.localizedDescription)")

        // Log nested causes
        var current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
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
