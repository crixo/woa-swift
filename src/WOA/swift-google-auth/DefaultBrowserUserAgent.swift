import AppKit
import AppAuth

/// Opens the Google sign-in page in the user's **default browser** (whatever is set in
/// System Settings → Desktop & Dock → Default web browser), using the browser's existing
/// Google session/cookies. The result comes back through the loopback redirect handled by AppAuth.
final class DefaultBrowserUserAgent: NSObject, OIDExternalUserAgent {

    func present(_ request: OIDExternalUserAgentRequest, session: OIDExternalUserAgentSession) -> Bool {
        guard let url = request.externalUserAgentRequestURL() else { return false }
        return NSWorkspace.shared.open(url)
    }

    func dismiss(animated: Bool, completion: @escaping () -> Void) {
        // A system browser tab can't be closed programmatically; just bring the app back to the front.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            completion()
        }
    }
}
