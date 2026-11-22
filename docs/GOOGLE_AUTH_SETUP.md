# Google authentication and Gmail service

Google sign-in is implemented in `src/WOA/swift-google-auth/` using AppAuth.
It is optional and is disabled by default. `GmailService` can send mail when
the user granted the Gmail send scope, but there is currently no email-sending
workflow in the app UI.

## Current configuration

The checked-in physical plist is
[`src/WOA/Resources/Info.plist`](../src/WOA/Resources/Info.plist). It contains:

- `GoogleIOSClientID`, set from the `GOOGLE_IOS_CLIENT_ID` build setting.
- A fixed custom URL scheme for the configured OAuth client ID. The scheme
  must match the reversed client ID.
- No `GoogleClientID` or `GoogleClientSecret` keys for the Desktop client.

The Xcode project references `src/Config/Secrets.xcconfig`; that file is
ignored by Git and is not included. Create it locally with the appropriate
`GOOGLE_IOS_CLIENT_ID` value if you use the iOS OAuth client. The client ID must
match the reversed scheme already present in `Info.plist`; changing clients
requires updating that scheme as well. Never commit OAuth credentials or
private keys. Values compiled into `Info.plist` can be read from the app
bundle; installed-app client IDs are not secrets.

The app links AppAuth and has the network client/server sandbox entitlements
needed for API calls, loopback auth, and Google redirects. The alternative
Desktop client path exists in code, but this repository does not currently
provide its required plist keys.

## Enable sign-in

The Settings view exposes **Richiedi autenticazione Google** and a client
picker. The default client choice is **Desktop app**; select **Client iOS**
when the configured iOS client ID and URL scheme are in place. Enabling Google
auth requires the selected client configuration in the built app's plist.

For Google Cloud, configure an OAuth consent screen and a Desktop or iOS OAuth
client as appropriate. The app requests OpenID, email, profile, and
`https://www.googleapis.com/auth/gmail.send` during interactive sign-in. Add
the Gmail API if the Gmail service will be used. Google's console requirements,
testing-user restrictions, and verification rules can change; consult current
Google documentation.

> **Current startup limitation:** `WOA.init()` loads settings and then replaces
> the loaded store with a new default store. This means the app may not apply a
> saved Google-auth toggle/client selection at launch. See
> [Project settings](project-settings.md). The settings UI can save the
> preferences, but this startup defect must be fixed before relying on them.

## Sign-in behavior

- With authentication disabled, `AuthGate` shows the app content directly.
- With authentication enabled, startup checks for configured credentials and
  a stored session, then verifies the Google browser session using the default
  browser. The browser check has a 120-second timeout.
- Interactive login requests offline access and asks the user to select an
  account and consent. The Desktop client uses a loopback redirect; the iOS
  client uses its custom URL scheme.
- A stored session created by the other client type is discarded.
- Offline startup is allowed only if an earlier online check or interactive
  sign-in succeeded. The remembered-success flag is in `UserDefaults` and has
  no age limit.
- The logout button calls `signOut()` and removes the local session; it does
  not revoke the Google grant. Browser sign-out while WOA is running does not
  immediately change the app session.

This is a client-side UI gate, not server-side access control for local data.

## Token storage and Gmail service

AppAuth authorization state is archived to the macOS Keychain using the
`google.oauth.authstate` account and the app bundle identifier as service.
Refreshed tokens are persisted. Do not put OAuth tokens in settings JSON,
logs, or source control. The last-successful-startup and OAuth client-type
markers are small `UserDefaults` values, not the token store.

`GmailService.send(to:subject:body:isHTML:cc:bcc:)` requires the granted
`gmail.send` scope, obtains a fresh access token, and sends to the Gmail API.
It reports invalid recipients, missing scope, HTTP errors, and transport
errors. The implementation supports plain text or HTML bodies; it does not
implement attachments.

## Troubleshooting

- **Missing Google client configuration:** inspect the built
  `WOA.app/Contents/Info.plist`; confirm the iOS client ID build setting or,
  for Desktop, the absent required plist keys.
- **Google iOS redirect does not return to WOA:** ensure the URL scheme exactly
  matches the reverse of `GoogleIOSClientID`.
- **Browser authorization cannot reach the app:** check the sandbox's network
  server entitlement and local loopback access.
- **Google auth choice reverts or does not apply after relaunch:** the current
  settings-store initialization defect is documented above.
- **Gmail send reports missing scope:** sign in again and grant the Gmail send
  permission.
- **OAuth testing users cannot sign in:** check the consent screen audience
  and test-user configuration in Google Cloud.
