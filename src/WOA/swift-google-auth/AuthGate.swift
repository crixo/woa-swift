import SwiftUI

/// Wraps the app's root content.
/// - `isEnabled == false`: content is shown directly, no Google involved.
/// - `isEnabled == true`: a Google check runs at launch (default browser); content is shown only when it passes.
///
/// Make sure your settings are fully loaded before creating this view, otherwise a default
/// `googleAuthEnabled == false` would let the content show before the real value is known.
struct AuthGate<Content: View>: View {
    @EnvironmentObject private var auth: GoogleAuthService

    let isEnabled: Bool
    /// Which Google OAuth client to use (`.desktop` needs a client secret, `.ios` does not).
    var clientType: GoogleClientType = .desktop
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if !isEnabled || auth.isSignedIn {
                content()
            } else if auth.state == .checking {
                VStack(spacing: 12) {
                    ProgressView("Checking your Google session…")
                    Text("If your browser asks you to sign in to Google, complete it there.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Cancel") { auth.cancelAuthorization() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GoogleLoginView()
            }
        }
        .task(id: isEnabled) {
            guard isEnabled else { return }
            auth.clientType = clientType
            await auth.performStartupCheck()
        }
    }
}

// MARK: - Login screen

struct GoogleLoginView: View {
    @EnvironmentObject private var auth: GoogleAuthService

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Sign in required")
                .font(.title2.bold())

            Text("Your default web browser will open so you can sign in with Google.")
                .foregroundStyle(.secondary)

            if auth.state == .signingIn {
                ProgressView("Waiting for the browser…")
            } else {
                Button("Sign in with Google") {
                    Task { await auth.signIn() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if case .failed(let message) = auth.state {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Logout button

/// Place anywhere in your UI (toolbar, settings, menu). It only appears while a Google user is signed in,
/// so it is automatically hidden when `googleAuthEnabled` is false.
struct GoogleLogoutButton: View {
    @EnvironmentObject private var auth: GoogleAuthService

    var body: some View {
        if let email = auth.userEmail {
            Button {
                auth.signOut()
            } label: {
                Label("Sign out (\(email))", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .help("Sign out of Google. A browser sign-in will be required at the next launch.")
        }
    }
}
