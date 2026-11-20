import AppKit
import AppAuth
import Foundation

// MARK: - Client type

/// Which kind of Google OAuth client the app authenticates with.
enum GoogleClientType: String {
    /// "Desktop app" client. The browser returns to a local listener on 127.0.0.1.
    /// Google requires the client secret for the code exchange (it is not confidential).
    case desktop
    /// "iOS" client. No client secret. The browser returns through a custom URL scheme
    /// (`com.googleusercontent.apps.<id>:/oauth2redirect`) registered by the app.
    case ios
}

// MARK: - Configuration

/// Reads the OAuth client credentials from Info.plist.
///
/// Desktop client:  GoogleClientID, GoogleClientSecret
/// iOS client:      GoogleIOSClientID  (+ a URL scheme registered in Info.plist, see GOOGLE_AUTH_SETUP.md)
enum GoogleAuthConfig {
    static let issuer = URL(string: "https://accounts.google.com")!

    static let gmailSendScope = "https://www.googleapis.com/auth/gmail.send"

    /// Scopes requested at sign-in. Remove `gmailSendScope` if you don't need to send mail.
    static let scopes = [OIDScopeOpenID, OIDScopeEmail, OIDScopeProfile, gmailSendScope]

    /// How long the launch-time browser check may take before it is considered inconclusive.
    /// Generous, because if the browser is not signed in to Google the user signs in during this check.
    static let browserCheckTimeout: TimeInterval = 120

    // Desktop client
    static var clientID: String { value(for: "GoogleClientID") }
    static var clientSecret: String { value(for: "GoogleClientSecret") }

    // iOS client
    static var iosClientID: String { value(for: "GoogleIOSClientID") }

    /// `com.googleusercontent.apps.<client id prefix>:/oauth2redirect`, derived from the iOS client ID.
    static var iosRedirectURL: URL? {
        let suffix = ".apps.googleusercontent.com"
        let id = iosClientID
        guard id.hasSuffix(suffix) else { return nil }
        let prefix = String(id.dropLast(suffix.count))
        return URL(string: "com.googleusercontent.apps.\(prefix):/oauth2redirect")
    }

    static func isConfigured(for type: GoogleClientType) -> Bool {
        switch type {
        case .desktop: return !clientID.isEmpty && !clientSecret.isEmpty
        case .ios: return iosRedirectURL != nil
        }
    }

    private static func value(for key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }
}

// MARK: - Errors

enum GoogleAuthError: LocalizedError {
    case missingConfiguration(GoogleClientType)
    case discoveryFailed(String)
    case loopbackFailed(String)
    case notSignedIn
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(.desktop):
            return "Google client ID/secret are missing from Info.plist (GoogleClientID, GoogleClientSecret)."
        case .missingConfiguration(.ios):
            return "The Google iOS client ID is missing or invalid in Info.plist (GoogleIOSClientID)."
        case .discoveryFailed(let m): return "Could not reach Google: \(m)"
        case .loopbackFailed(let m): return "Could not start the local sign-in listener: \(m)"
        case .notSignedIn: return "You are not signed in with Google."
        case .cancelled: return "Sign-in was cancelled."
        }
    }
}

// MARK: - Persists refreshed tokens automatically

private final class AuthStateSaver: NSObject, OIDAuthStateChangeDelegate {
    private let persist: (OIDAuthState) -> Void
    init(persist: @escaping (OIDAuthState) -> Void) { self.persist = persist }
    func didChange(_ state: OIDAuthState) { persist(state) }
}

// MARK: - Receives the custom-URL-scheme redirect (iOS client type)

/// macOS delivers a custom-scheme URL to the app as an Apple Event ("get URL").
private final class RedirectReceiver: NSObject {
    private let onURL: @MainActor (URL) -> Void

    init(onURL: @escaping @MainActor (URL) -> Void) {
        self.onURL = onURL
    }

    @objc func handle(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string) else { return }
        MainActor.assumeIsolated { onURL(url) }   // Apple Events are delivered on the main thread
    }
}

// MARK: - Service

@MainActor
final class GoogleAuthService: ObservableObject {

    enum State: Equatable {
        /// The launch-time check has not finished yet.
        case checking
        case signedOut
        case signingIn
        case signedIn(email: String)
        case failed(String)
    }

    @Published private(set) var state: State = .checking

    /// Which OAuth client to use. Set (by `AuthGate`) before the launch check.
    var clientType: GoogleClientType = .desktop

    private static let keychainAccount = "google.oauth.authstate"
    /// True when the last launch-time check (or interactive sign-in) succeeded online.
    private static let checkSucceededKey = "GoogleAuth.lastStartupCheckSucceeded"
    /// Which client type created the stored session (tokens can't be refreshed by another client).
    private static let sessionClientTypeKey = "GoogleAuth.sessionClientType"

    private var authState: OIDAuthState?
    private var saver: AuthStateSaver?
    private var startupCheckDone = false
    private var activeFlow: (any OIDExternalUserAgentSession)?
    private var redirectReceiver: RedirectReceiver?

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    var userEmail: String? {
        if case .signedIn(let email) = state { return email }
        return nil
    }

    /// True when the user granted the Gmail "send" permission.
    var hasGmailSendScope: Bool {
        let granted = authState?.lastTokenResponse?.scope ?? authState?.scope ?? ""
        return granted.split(separator: " ").contains(Substring(GoogleAuthConfig.gmailSendScope))
    }

    // MARK: Launch-time check

    /// Runs once per app launch (when `googleAuthEnabled` is true).
    ///
    /// | Situation                                              | Result                                           |
    /// |--------------------------------------------------------|--------------------------------------------------|
    /// | No stored session                                      | login screen (browser sign-in)                   |
    /// | Stored session made by the other client type           | session dropped, login screen                    |
    /// | Online, browser still signed in to the same account    | signed in                                        |
    /// | Online, browser signed out                             | Google's sign-in page opens in the browser       |
    /// | Online, other account / sign-in not completed          | stored session dropped, login screen             |
    /// | Online, check inconclusive (timeout, tab closed)       | login screen with a message                      |
    /// | Offline, previous launch check succeeded               | signed in + `AppLogger.warning`                  |
    /// | Offline, no previous successful check                  | login screen with a message                      |
    func performStartupCheck() async {
        guard !startupCheckDone else { return }
        startupCheckDone = true
        state = .checking

        guard GoogleAuthConfig.isConfigured(for: clientType) else {
            state = .failed(GoogleAuthError.missingConfiguration(clientType).localizedDescription)
            return
        }

        guard let stored = loadStoredAuthState() else {
            state = .signedOut
            return
        }

        // A session created by the other client type can't be refreshed by this one: start clean.
        let storedType = UserDefaults.standard.string(forKey: Self.sessionClientTypeKey) ?? GoogleClientType.desktop.rawValue
        guard storedType == clientType.rawValue else {
            forgetSession()
            state = .signedOut
            return
        }

        adopt(stored)
        let email = Self.email(from: stored)

        // 1. Offline? Don't even try to open the browser.
        guard await NetworkMonitor.isOnline() else {
            enterOfflineMode()
            return
        }

        // 2. Online: ask Google, through the default browser, whether the browser is signed in to this
        //    account. The result is only a check: it is NOT adopted, because it carries no refresh token.
        do {
            // Launch check: no `prompt` parameter, so Google decides. Browser signed in to this account and
            // permissions already granted → instant redirect, no screen. Otherwise Google shows its normal
            // sign-in page in the browser. (`prompt=none` is not used: Google answers it with
            // `interaction_required` for this kind of client.) Identity only: no Gmail scope, no refresh token.
            let result = try await authorize(prompt: nil, loginHint: email,
                                             timeout: GoogleAuthConfig.browserCheckTimeout,
                                             scopes: [OIDScopeOpenID, OIDScopeEmail],
                                             offline: false)
            let browserEmail = Self.email(from: result)
            if !browserEmail.isEmpty, browserEmail.lowercased() != email.lowercased() {
                forgetSession()
                state = .failed("The Google account in your browser is different. Please sign in again.")
                return
            }
            setLastCheckSucceeded(true)
            state = .signedIn(email: email)
        } catch GoogleAuthError.discoveryFailed {
            // Network said "online" but Google is unreachable: treat as offline.
            enterOfflineMode()
        } catch let error as NSError where error.domain == OIDOAuthAuthorizationErrorDomain {
            AppLogger.warning("Google authentication: the browser check was rejected by Google (domain: \(error.domain), code: \(error.code), \(error.localizedDescription)).")
            // Google answered with an OAuth error: the browser is not signed in to this Google account.
            forgetSession()
            state = .failed("You are not signed in to Google in your browser. Please sign in.")
        } catch {
            // Timeout, cancelled or closed tab: we could not verify, so the user must sign in again.
            AppLogger.warning("Google authentication: the browser check did not complete (\(error.localizedDescription)).")
            setLastCheckSucceeded(false)
            authState = nil
            state = .failed("Your Google session could not be verified in the browser. Please sign in.")
        }
    }

    private func enterOfflineMode() {
        if UserDefaults.standard.bool(forKey: Self.checkSucceededKey), let authState {
            AppLogger.warning(
                "Google authentication: no internet connection, the Google session could not be verified. "
                + "Access granted because the check at the previous startup succeeded. "
                + "The check will run again at the next application launch."
            )
            state = .signedIn(email: Self.email(from: authState))
        } else {
            authState = nil
            state = .failed("You are offline and your Google session has not been verified yet. Connect to the internet and sign in.")
        }
    }

    // MARK: Interactive sign in (default browser)

    func signIn() async {
        guard GoogleAuthConfig.isConfigured(for: clientType) else {
            state = .failed(GoogleAuthError.missingConfiguration(clientType).localizedDescription)
            return
        }
        state = .signingIn

        guard await NetworkMonitor.isOnline() else {
            state = .failed("No internet connection. Connect to the internet to sign in with Google.")
            return
        }

        do {
            // "select_account" always shows the account chooser (forces an explicit choice after logout);
            // "consent" guarantees a refresh token is issued.
            let newState = try await authorize(prompt: "consent select_account", loginHint: nil, timeout: nil)

            let email = Self.email(from: newState)

            adopt(newState)
            persist(newState)
            setLastCheckSucceeded(true)
            state = .signedIn(email: email)
        } catch GoogleAuthError.discoveryFailed {
            state = .failed("Google is not reachable right now. Check your connection and try again.")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Stops a browser authorization that is waiting for the user (launch check or sign-in).
    /// The waiting call ends as "cancelled" and the login screen is shown.
    func cancelAuthorization() {
        activeFlow?.cancel(completion: nil)
    }

    // MARK: Logout

    /// Logout button: forgets the stored session and returns to the login screen.
    /// Because the stored session is gone, the next launch also requires a browser sign-in
    /// (with the Google account chooser).
    func signOut() {
        forgetSession()
        state = .signedOut
    }

    /// Same as `signOut()`, and also revokes the grant on Google's side.
    func signOutAndRevoke() async {
        if let token = authState?.lastTokenResponse?.refreshToken ?? authState?.lastTokenResponse?.accessToken,
           let url = URL(string: "https://oauth2.googleapis.com/revoke") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "token=\(token)".data(using: .utf8)
            _ = try? await URLSession.shared.data(for: request)
        }
        signOut()
    }

    // MARK: Tokens for API calls

    /// Returns a valid access token, refreshing it with the stored refresh token if it has expired.
    /// Throws (e.g. a network error) without signing the user out.
    func freshAccessToken() async throws -> String {
        guard let authState else { throw GoogleAuthError.notSignedIn }
        return try await withCheckedThrowingContinuation { continuation in
            authState.performAction { accessToken, _, error in
                if let accessToken {
                    continuation.resume(returning: accessToken)
                } else {
                    continuation.resume(throwing: error ?? GoogleAuthError.notSignedIn)
                }
            }
        }
    }

    // MARK: Authorization via the default browser

    private func authorize(
        prompt: String?,
        loginHint: String?,
        timeout: TimeInterval?,
        scopes: [String] = GoogleAuthConfig.scopes,
        offline: Bool = true
    ) async throws -> OIDAuthState {
        guard GoogleAuthConfig.isConfigured(for: clientType) else {
            throw GoogleAuthError.missingConfiguration(clientType)
        }
        let configuration = try await discoverConfiguration()

        // How the browser comes back to the app depends on the client type.
        var loopback: OIDRedirectHTTPHandler?
        let redirectURL: URL
        switch clientType {
        case .desktop:
            // Loopback redirect (http://127.0.0.1:<random port>), served by AppAuth.
            let handler = OIDRedirectHTTPHandler(successURL: nil)
            var listenerError: NSError?
            let url = handler.startHTTPListener(&listenerError)
            if let listenerError { throw GoogleAuthError.loopbackFailed(listenerError.localizedDescription) }
            loopback = handler
            redirectURL = url
        case .ios:
            // Custom URL scheme, delivered to the app as an Apple Event.
            guard let url = GoogleAuthConfig.iosRedirectURL else {
                throw GoogleAuthError.missingConfiguration(.ios)
            }
            installRedirectReceiver()
            redirectURL = url
        }
        defer { loopback?.cancelHTTPListener() }
        defer { activeFlow = nil }

        var parameters: [String: String] = [:]
        if let prompt { parameters["prompt"] = prompt }
        // Offline access (refresh token) is only needed for the real sign-in. Asking for it in the
        // launch check can make Google demand an interactive consent screen.
        if offline { parameters["access_type"] = "offline" }
        if let loginHint { parameters["login_hint"] = loginHint }

        let request: OIDAuthorizationRequest
        switch clientType {
        case .desktop:
            request = OIDAuthorizationRequest(
                configuration: configuration,
                clientId: GoogleAuthConfig.clientID,
                clientSecret: GoogleAuthConfig.clientSecret,
                scopes: scopes,
                redirectURL: redirectURL,
                responseType: OIDResponseTypeCode,
                additionalParameters: parameters
            )
        case .ios:
            // No client secret: authorization code + PKCE only.
            request = OIDAuthorizationRequest(
                configuration: configuration,
                clientId: GoogleAuthConfig.iosClientID,
                scopes: scopes,
                redirectURL: redirectURL,
                responseType: OIDResponseTypeCode,
                additionalParameters: parameters
            )
        }

        let timeoutTask = timeout.map { seconds in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                self.activeFlow?.cancel(completion: nil)
            }
        }
        defer { timeoutTask?.cancel() }

        return try await withCheckedThrowingContinuation { continuation in
            let flow = OIDAuthState.authState(
                byPresenting: request,
                externalUserAgent: DefaultBrowserUserAgent()
            ) { authState, error in
                if let authState {
                    continuation.resume(returning: authState)
                } else if let error = error as NSError?,
                          error.domain == OIDGeneralErrorDomain,
                          error.code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue {
                    continuation.resume(throwing: GoogleAuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? GoogleAuthError.notSignedIn)
                }
            }
            loopback?.currentAuthorizationFlow = flow   // desktop: lets the listener resume the flow
            self.activeFlow = flow                      // ios: the Apple Event handler resumes it
        }
    }

    /// Registers the handler that receives `com.googleusercontent.apps.<id>:/oauth2redirect?code=…`.
    private func installRedirectReceiver() {
        let receiver = RedirectReceiver { [weak self] url in
            _ = self?.activeFlow?.resumeExternalUserAgentFlow(with: url)
        }
        redirectReceiver = receiver   // NSAppleEventManager does not retain its handlers
        NSAppleEventManager.shared().setEventHandler(
            receiver,
            andSelector: #selector(RedirectReceiver.handle(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    // MARK: Private helpers

    private func discoverConfiguration() async throws -> OIDServiceConfiguration {
        try await withCheckedThrowingContinuation { continuation in
            OIDAuthorizationService.discoverConfiguration(forIssuer: GoogleAuthConfig.issuer) { config, error in
                if let config {
                    continuation.resume(returning: config)
                } else {
                    continuation.resume(throwing: GoogleAuthError.discoveryFailed(error?.localizedDescription ?? "unknown error"))
                }
            }
        }
    }

    private func loadStoredAuthState() -> OIDAuthState? {
        do {
            guard let data = try KeychainStore.load(account: Self.keychainAccount) else { return nil }
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data)
        } catch {
            // Corrupt or unreadable: start clean.
            forgetSession()
            return nil
        }
    }

    private func adopt(_ newState: OIDAuthState) {
        let saver = AuthStateSaver { [weak self] updated in
            // Called by AppAuth whenever tokens are refreshed.
            Task { @MainActor in self?.persist(updated) }
        }
        newState.stateChangeDelegate = saver
        self.saver = saver
        self.authState = newState
    }

    private func persist(_ authState: OIDAuthState) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: authState, requiringSecureCoding: true)
            try KeychainStore.save(data, account: Self.keychainAccount)
            UserDefaults.standard.set(clientType.rawValue, forKey: Self.sessionClientTypeKey)
        } catch {
            AppLogger.warning("Google authentication: could not store tokens in the Keychain: \(error.localizedDescription)")
        }
    }

    /// Drops the in-memory and stored session (does not change `state`).
    private func forgetSession() {
        authState = nil
        saver = nil
        try? KeychainStore.delete(account: Self.keychainAccount)
        UserDefaults.standard.removeObject(forKey: Self.checkSucceededKey)
        UserDefaults.standard.removeObject(forKey: Self.sessionClientTypeKey)
    }

    private func setLastCheckSucceeded(_ succeeded: Bool) {
        UserDefaults.standard.set(succeeded, forKey: Self.checkSucceededKey)
    }

    private static func email(from authState: OIDAuthState) -> String {
        guard let raw = authState.lastTokenResponse?.idToken,
              let token = OIDIDToken(idTokenString: raw),
              let email = token.claims["email"] as? String
        else { return "" }
        return email
    }
}
