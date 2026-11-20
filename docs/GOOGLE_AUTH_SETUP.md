# Google Authentication & Gmail Sending — Setup Guide

This guide covers:

1. How the authentication behaves
2. Configuring the Google Cloud project and OAuth client
3. Wiring the Swift files into the app
4. How tokens are stored
5. Sending email with the Gmail API using the stored token

> Google Cloud Console menus are renamed from time to time (the OAuth screens now live under **Google Auth Platform**). If a label differs slightly, follow the equivalent item and check the current docs at <https://developers.google.com/identity/protocols/oauth2/native-app>.

---

## 1. Behavior

Everything is driven by `AppSettings.googleAuthEnabled`. When it is `false`, the app opens with no login and Google is never contacted.

When it is `true`, **the Google check runs once, at every app launch**, through the user's **default web browser**:

| Situation at launch | Result |
|---|---|
| No stored session | Login screen → browser sign-in (Google account chooser) |
| Online, browser is still signed in to the same Google account | User enters (Google redirects straight back, a browser tab flashes) |
| Online, browser is signed out | Google shows its sign-in page in the browser; once the user signs in there, the app opens |
| Online, browser signed in to another account, or the user does not complete the sign-in | Stored session dropped → login screen |
| Online, check inconclusive (no answer within 120 s, tab closed, Cancel pressed) | Login screen with a message |
| **Offline**, and the check at the previous startup succeeded | User enters; `AppLogger.warning(...)` records it |
| Offline, and there was no successful previous check | Login screen with a message |

During a running session:

| Event | Result |
|---|---|
| User signs out of Google in the browser | **Nothing happens.** The user keeps working; the check runs at the next launch. |
| Internet lost | Nothing happens; API calls such as sending email fail with a network error until the connection returns. |
| User presses the **logout button** | Stored tokens are removed and the login screen is shown. Because no session is stored, the next launch also requires a browser sign-in (account chooser). |

Notes:
- "Previous startup check succeeded" is a flag saved in `UserDefaults` (`GoogleAuth.lastStartupCheckSucceeded`). It is set after a successful interactive sign-in or a successful launch check, and removed on logout or when the session is dropped.
- Offline entry is not time-limited: as long as the last online check succeeded, the user can keep launching offline. If you want a grace period (for example 14 days), store a date next to the flag and compare it in `enterOfflineMode()`.
- The online check is an authorization request with `login_hint=<email>`, identity scopes only (`openid`, `email`), no offline access and **no `prompt` parameter**, so Google decides: valid browser session and permissions already granted → instant redirect without any screen; otherwise Google shows its normal sign-in page and the user completes it in the browser. Its result is only used to verify the account; it is not adopted as the new session, because it carries no refresh token.
- `prompt=none` (a truly silent request) is deliberately **not** used: Google answers it with `interaction_required` for this kind of client, even when the browser is signed in.
- While the check waits for the browser, the app shows "Checking your Google session…" with a **Cancel** button (`auth.cancelAuthorization()`); cancelling leads to the login screen.
- The offline warning is written with `AppLogger.warning(_:)`. The code assumes that signature (a single `String`); adjust the two call sites in `GoogleAuthService.swift` if your logger differs. The email address is deliberately not written to the log.
- Opening the browser at each launch leaves one browser tab open; a native app cannot close it.

---

## 2. Google Cloud configuration

### 2.1 Create a project
1. Open <https://console.cloud.google.com/>.
2. Project picker → **New Project** → name it (e.g. `MyDesktopApp`) → **Create**.

### 2.2 Enable the Gmail API
1. **APIs & Services → Library**.
2. Search **Gmail API** → **Enable**.

(Sign-in alone needs no API. Gmail API is only for sending mail.)

### 2.3 Configure the OAuth consent screen (Google Auth Platform)
1. **APIs & Services → OAuth consent screen** (or **Google Auth Platform → Branding**).
2. **App name**, **User support email**, **Developer contact email**.
3. **Audience / User type**:
   - **Internal** — only if you use Google Workspace and everybody is in your organization. No verification needed.
   - **External** — for any Google account (including personal Gmail).
4. **Data Access / Scopes** → **Add or remove scopes** and add:
   - `openid`
   - `.../auth/userinfo.email`
   - `.../auth/userinfo.profile`
   - `https://www.googleapis.com/auth/gmail.send` (only if you send email)
5. **Test users** (External + *Testing* status): add every Google account that will sign in during development.

### 2.4 "Testing" vs "In production" (important)
- **Testing**: only listed test users can sign in, and **refresh tokens expire after 7 days**. After that the stored session stops working and the user must sign in again (the launch check will send them to the login screen).
- **In production**: no 7-day expiry, any user can sign in. But `gmail.send` is a **sensitive scope**, so Google requires **app verification** (brand, privacy policy URL, scope justification, sometimes a demo video) before the general public can use it. Unverified apps show a warning screen and are capped at 100 users.
- If the app is only for you or your team, **Internal** (Workspace) avoids all of this.

### 2.5 Create the OAuth client
1. **APIs & Services → Credentials → Create credentials → OAuth client ID**.
2. **Application type: Desktop app**. Name it (e.g. `MyDesktopApp macOS`).
3. **Create**, then copy the **Client ID** and **Client secret**.

Notes:
- For Desktop clients, Google still issues a client secret and expects it in the token request. It is **not treated as confidential** for installed apps (security comes from PKCE and the user's consent), but don't publish it in a public repository.
- Desktop-app clients automatically allow loopback redirects (`http://127.0.0.1:<any port>`); you do not register redirect URIs.

### 2.6 Optional: a second OAuth client of type "iOS" (no client secret)

The app can authenticate with either client type, selected by `AppSettings.googleAuthUseIOSClient`:

| | **Desktop app** client (default) | **iOS** client |
|---|---|---|
| Client secret | Required by Google (not confidential) | None |
| How the browser returns to the app | Local listener on `127.0.0.1` | Custom URL scheme `com.googleusercontent.apps.<id>:/oauth2redirect` |
| Page shown in the browser at the end | "Authorization complete. Return to the app." | None: the browser jumps to the app, usually after an "Open WOA?" prompt |
| Entitlement needed | `network.server` + `network.client` | `network.client` |
| Info.plist | `GoogleClientID`, `GoogleClientSecret` | `GoogleIOSClientID` + a URL type |

**Do I need a separate Google app registration?** No. Use the **same Google Cloud project**: the same Gmail API, the same consent screen, the same scopes and the same test users apply to every OAuth client in the project. You only create one more **OAuth client**: **APIs & Services → Credentials → Create credentials → OAuth client ID → Application type: iOS**, with your app's **Bundle ID**. An OAuth client's type can't be changed afterwards, so the Desktop client can't be converted: keep it and add the iOS one. Google shows a client ID and no secret for the iOS type.

Google's own Sign-In SDK uses the iOS client type for macOS apps, but it is not the documented path for generic desktop apps, so test it on your own machine before relying on it.

A stored session belongs to the client that created it: tokens issued to one client can't be refreshed by the other. When the setting switches the client type, the app drops the stored session at the next launch and shows the login screen.

---

## 3. Xcode project configuration

### 3.1 Add the AppAuth package
Xcode → **File → Add Package Dependencies…** →
`https://github.com/openid/AppAuth-iOS` → add the **AppAuth** product to your macOS target.

### 3.2 Info.plist keys

```xml
<key>GoogleClientID</key>
<string>YOUR_CLIENT_ID.apps.googleusercontent.com</string>
<key>GoogleClientSecret</key>
<string>YOUR_CLIENT_SECRET</string>
```

The key names must be exactly `GoogleClientID` and `GoogleClientSecret`: the code reads them by these names.

**Where to add them**
- Many Xcode projects have no `Info.plist` file and generate it from build settings. In that case use target **WOA → Info → Custom macOS Application Target Properties**, hover a row, click **+**, type the key name, set the type to **String** and the value. These custom keys are merged into the generated plist.
- If the project has a real `Info.plist` file, add the `<key>`/`<string>` lines above inside the top-level `<dict>`.

**Keeping the values out of git (optional)**

Use an `.xcconfig` file, and put variable references in Info.plist instead of the real values:

| Key | Type | Value |
|---|---|---|
| `GoogleClientID` | String | `$(GOOGLE_CLIENT_ID)` |
| `GoogleClientSecret` | String | `$(GOOGLE_CLIENT_SECRET)` |

1. Create `src/Config/Secrets.xcconfig` (outside `src/WOA/`, so it is not copied into the app):
   ```
   GOOGLE_CLIENT_ID = 1234567890-abc.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET = GOCSPX-xxxxxxxx
   ```
2. Add it to `.gitignore` before the first commit, and commit a `src/Config/Secrets.xcconfig.example` with placeholders:
   ```ignore
   # Secrets
   src/Config/Secrets.xcconfig
   ```
   Check with `git check-ignore -v src/Config/Secrets.xcconfig`.
3. Select the **project** (blue icon) → **Info → Configurations**, and for both **Debug** and **Release** choose `Secrets` on the project row. Leave the target rows on *None*.
4. Check: target → **Build Settings** → search `GOOGLE`; both user-defined settings should show your values.
5. On a CI machine, create the file before building from the CI's secret variables.

The values are **not** hidden in the built app: Xcode substitutes them into the app's Info.plist, where anyone can read them. For an installed-app OAuth client this is expected (see the note on the client secret in section 2.5). Always check a **Release** build: open `WOA.app/Contents/Info.plist` and make sure both keys contain real values. If they are empty, sign-in shows the "missing from Info.plist" error.

### 3.2b Info.plist entries for the iOS client type

Only needed if you use `googleAuthUseIOSClient`.

1. **Client ID key** (String): `GoogleIOSClientID` = `1234567890-abc.apps.googleusercontent.com`. With the `.xcconfig` setup, use `$(GOOGLE_IOS_CLIENT_ID)` and define the value in `Secrets.xcconfig`.
2. **URL type**: the redirect scheme is the client ID reversed. For the client ID `1234567890-abc.apps.googleusercontent.com`, the scheme is `com.googleusercontent.apps.1234567890-abc`.
   - Xcode: target **WOA → Info → URL Types → +**, set **Identifier** to your bundle ID, **URL Schemes** to the scheme above, **Role** to *Editor*.
   - Or in a real `Info.plist`:
     ```xml
     <key>CFBundleURLTypes</key>
     <array>
       <dict>
         <key>CFBundleURLName</key>
         <string>YOUR.BUNDLE.ID</string>
         <key>CFBundleURLSchemes</key>
         <array>
           <string>com.googleusercontent.apps.1234567890-abc</string>
         </array>
       </dict>
     </array>
     ```
   - With the `.xcconfig` setup, define `GOOGLE_IOS_REVERSED_CLIENT_ID = com.googleusercontent.apps.1234567890-abc` in `Secrets.xcconfig` and use `$(GOOGLE_IOS_REVERSED_CLIENT_ID)` as the URL scheme.
3. The scheme in Info.plist must match the client ID exactly, otherwise the browser's answer never reaches the app.

### 3.3 Sandbox entitlements (if App Sandbox is enabled)

Add these two entries to the app's `.entitlements` file, inside the top-level `<dict>`, keeping the entries that are already there:

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

- `network.client` (**Outgoing Connections**): lets the app reach Google (endpoint discovery, token exchange) and the Gmail API.
- `network.server` (**Incoming Connections**): lets the app run the local listener on `127.0.0.1` that receives Google's redirect. Without it, the browser's answer never arrives and sign-in waits forever. Only the **Desktop** client type uses it; the iOS client type receives the redirect through its URL scheme instead.

Alternatively, set them in Xcode: target **WOA → Signing & Capabilities → App Sandbox → Network**, tick **Outgoing Connections (Client)** and **Incoming Connections (Server)**. Xcode writes the same keys into the `.entitlements` file.

After changing entitlements, do **Product → Clean Build Folder** and run again. If the app is not sandboxed, nothing is needed.

### 3.4 Files to add to the target

| File | Role |
|---|---|
| `AppSettings.swift` | Your struct with two added optional properties: `googleAuthEnabled: Bool?` and `googleAuthUseIOSClient: Bool?` (`nil` is treated as `false`). Serialization stays with your existing `ConfigurationService`. |
| `GoogleAuthService.swift` | Launch check, sign-in, logout, token access (AppAuth). |
| `DefaultBrowserUserAgent.swift` | Opens the Google page in the user's default browser. |
| `NetworkMonitor.swift` | Quick online/offline detection. |
| `KeychainStore.swift` | Stores the auth state in the macOS Keychain. |
| `AuthGate.swift` | `AuthGate` (root wrapper), `GoogleLoginView`, `GoogleLogoutButton`. |
| `GmailService.swift` | Sends email through the Gmail API. |

---

## 4. Integrating in the app

```swift
@main
struct MyApp: App {
    @StateObject private var auth = GoogleAuthService()
    @StateObject private var settingsStore = SettingsStore()   // your existing store

    var body: some Scene {
        WindowGroup {
            AuthGate(
                isEnabled: settingsStore.settings.googleAuthEnabled ?? false,
                clientType: (settingsStore.settings.googleAuthUseIOSClient ?? false) ? .ios : .desktop
            ) {
                ContentView()          // your existing root view
            }
            .environmentObject(auth)
        }
    }
}
```

Logout button: put it anywhere (toolbar, settings, menu). It appears only while a Google user is signed in, so it is hidden automatically when `googleAuthEnabled` is `false`:

```swift
.toolbar {
    ToolbarItem { GoogleLogoutButton() }
}
```

Use `await auth.signOutAndRevoke()` instead of `auth.signOut()` if you also want to revoke the grant at Google.

> **Any Google account can sign in.** There is no email allow-list: whoever can sign in to Google with the app's OAuth client is let in. Restrict who can authenticate with the **Internal** audience (Workspace), or with the **Test users** list while the app is in Testing (section 2.3/2.4).

> **Older settings files.** `googleAuthEnabled` is declared as `Bool?` on purpose. Swift's synthesized `Decodable` fails on JSON that lacks a non-optional key, even when the property has a default value, and `ConfigurationService.load()` answers any decoding failure with `.default`: the user would silently lose the stored database connection, and the next save would overwrite the file. With an optional property a missing key decodes as `nil`. Always read it as `settings.googleAuthEnabled ?? false`.

> **Load settings first.** `AuthGate` trusts `isEnabled`. If your settings load asynchronously and `googleAuthEnabled` is briefly `false` (the default), the content would show before the real value arrives. Create the gate only after settings have loaded.

> **Security note:** this gate is a client-side check. It decides what the UI shows, but it does not protect your database or files. If those need real protection, the backend must also verify the user's identity.

---

## 4b. Step-by-step: plugging the code into the WOA app

Project layout assumed:

```
src/
├── WOA/                  ← app sources (WOA.swift, …)
└── WOA.xcodeproj
```

The names `SettingsStore`, `ContentView` and `settings` below are placeholders: use the names of your own settings holder and root view.

1. **Add the files to the target.** Put the Swift files from section 3.4 in `src/WOA/` (or a subfolder). For each file, check in the File Inspector that the **WOA** target is ticked under *Target Membership*.

2. **Add two properties to `AppSettings`** (optional, so existing settings files still load):
   ```swift
   var googleAuthEnabled: Bool? = nil
   var googleAuthUseIOSClient: Bool? = nil   // true = iOS client (no secret), nil/false = Desktop client
   ```
   `"googleAuthUseIOSClient" : true` in the settings JSON switches to the iOS client type (see section 2.6).
   To turn the feature on, set `"googleAuthEnabled" : true` in the settings JSON file (its path is `AppSettingsStore.settingsFilePath`), or set the property and call `settingsStore.save(...)` from your settings UI.

3. **Create the auth service once, in the `@main` app struct, and wrap the root view in `AuthGate`:**
   ```swift
   @main
   struct WOAApp: App {
       @StateObject private var auth = GoogleAuthService()
       // your existing state/objects stay as they are

       var body: some Scene {
           WindowGroup {
               AuthGate(
                   isEnabled: settingsStore.settings.googleAuthEnabled ?? false,
                   clientType: (settingsStore.settings.googleAuthUseIOSClient ?? false) ? .ios : .desktop
               ) {
                   ContentView()          // your current root view
               }
               .environmentObject(auth)
           }
       }
   }
   ```
   - If the root view is currently called directly from `WindowGroup`, move it inside the gate's braces.
   - Create `AppSettingsStore` in the `@main` struct's `init`, call `store.load()` there (synchronously) and pass the store down to `MainView(settingsStore:)`, so the gate and the rest of the app share the same instance. `MainView` then holds it as `@ObservedObject` instead of creating it.
   - `.environmentObject(auth)` goes on the gate, so that the login screen, logout button and any other view can read it.

4. **Make sure settings are loaded before the gate appears.** `AuthGate` trusts `isEnabled`. If settings load asynchronously, the gate would see the default `false` for a moment and show the content. Either load the settings synchronously at startup, or show a loading view until they are ready and only then show `AuthGate`.

5. **Add the logout button** somewhere visible (toolbar, settings screen). It appears only while a Google user is signed in:
   ```swift
   .toolbar { ToolbarItem { GoogleLogoutButton() } }
   ```

6. **Use the Gmail service where you need to send email.** In a view, read the shared service from the environment, then create the Gmail service:
   ```swift
   @EnvironmentObject var auth: GoogleAuthService
   // ...
   try await GmailService(auth: auth).send(to: [...], subject: "...", body: "...")
   ```

7. **Other prerequisites** (see sections 2 and 3): Info.plist keys `GoogleClientID` and `GoogleClientSecret`, the AppAuth package linked to the WOA target, and, if the app is sandboxed, the outgoing and incoming network entitlements.

8. **Test:**
   1. Set `googleAuthEnabled = true` in the settings file and run the app: the login screen appears and the default browser opens.
   2. Sign in: the app content appears.
   3. Quit and relaunch: the browser flashes briefly (silent check) and the app opens.
   4. Sign out of Google in the browser while the app runs: nothing happens. Relaunch: the login screen appears.
   5. Turn the network off and relaunch (after a successful online launch): the app opens and `AppLogger.warning` records the offline entry.
   6. Press the logout button: the login screen appears, and the next launch requires a browser sign-in.

---

## 5. How the token is stored

- After sign-in, AppAuth's `OIDAuthState` (access token, **refresh token**, ID token, expiry, granted scopes) is archived with `NSKeyedArchiver` and saved as one generic-password item in the **macOS Keychain** (service = your bundle ID, account = `google.oauth.authstate`).
- AppAuth notifies the service whenever tokens are refreshed, and the new state is written back automatically.
- The refresh token is requested with `access_type=offline`; interactive sign-in also uses `prompt=consent` so it is issued reliably.
- `freshAccessToken()` returns a valid access token (about 1 hour lifetime) and transparently uses the refresh token when needed. **Call it right before each API request; never cache the raw access token yourself.** It throws on network errors without signing the user out.
- Never write tokens to `UserDefaults`, the settings JSON, logs, or git.

Stored refresh tokens stop working when: the user revokes access at <https://myaccount.google.com/permissions>, the password changes (for Gmail scopes), the app is in *Testing* for more than 7 days, the token is unused for 6 months, or the account exceeds the per-client token limit. Because the browser check at launch only verifies the browser session, an expired refresh token shows up the first time you call `freshAccessToken()` (for example when sending an email). Handle that error by calling `auth.signOut()` and asking the user to sign in again.

Because browser logout does not affect the app during a session, the stored tokens keep working for API calls (such as sending email) until the next launch check or logout.

---

## 5b. macOS Keychain prompt (for users and for the release process)

### What users may see
Occasionally at startup macOS asks: *"WOA wants to use your confidential information stored in 'com.woa.application' in your keychain."*

This is macOS protecting the stored Google session. Each Keychain item remembers which app (identified by its code signature) is allowed to read it. When the running app has a different signature than the copy that created the item, macOS asks the user.

| Button | Effect |
|---|---|
| **Always Allow** (recommended) | Allows this exact build from now on. Requires the user's macOS login password. |
| **Allow** | Allows this one time; the prompt returns at the next launch. |
| **Deny** | The app can't read the stored session: the user is shown the login screen and signs in with Google again. Nothing is lost or damaged. |

### When it appears
The app is not signed with a Developer ID, so it is signed ad hoc, and an ad-hoc signature changes with **every build**. The prompt therefore appears:
- the first launch after **installing a new version** (updates replace the app, and the new build has a new signature),
- when switching between different copies of the app (a development build and a downloaded release, for example),
- when the app is re-signed or rebuilt (developers).

It does not appear when the same build runs again.

### What the developer can do
- **Sign every release with the same self-signed code-signing certificate.** The signature then stays recognizable across versions, so users answer **Always Allow** once and are not asked again after updates. Create it once in *Keychain Access → Certificate Assistant → Create a Certificate…* (Identity Type: *Self Signed Root*, Certificate Type: *Code Signing*), back it up, and sign each release with it:
  ```
  codesign --force --deep --options runtime --preserve-metadata=entitlements \
           --sign "Your Certificate Name" WOA.app
  ```
  Or select it as the signing certificate in Xcode under *Signing & Capabilities* (manual signing). Gatekeeper still treats the app as from an unidentified developer; this only stabilizes the Keychain identity. If the certificate is lost and replaced, users see the prompt once more.
- **The data-protection Keychain is not an option without an Apple developer team.** It removes the prompts, but needs an app signed with a team identifier (otherwise Keychain calls fail with error `-34018`).
- **Not storing the session at all** removes the prompt, but then users must sign in with Google at every launch. This is not recommended.

### Suggested text for the user documentation
> **Keychain prompt.** After installing or updating WOA, macOS may ask whether WOA can use "your confidential information stored in com.woa.application" in your keychain. This is how WOA keeps your Google sign-in. Enter your macOS login password and click **Always Allow**. If you click **Deny**, nothing is damaged: WOA just asks you to sign in with Google again.

---

## 6. Sending email with the Gmail API

### 6.1 Usage

```swift
let gmail = GmailService(auth: auth)

do {
    let id = try await gmail.send(
        to: ["patient@example.com"],
        subject: "Appointment reminder",
        body: "Hello, this is a reminder for tomorrow at 10:00."
    )
    print("Sent, Gmail message id: \(id)")
} catch {
    print("Send failed: \(error.localizedDescription)")
}
```

HTML body: pass `isHTML: true`. Cc/Bcc: use the `cc:` / `bcc:` parameters. When offline, the call fails with a network error; show it to the user and let them retry.

### 6.2 What happens under the hood
- Endpoint: `POST https://gmail.googleapis.com/gmail/v1/users/me/messages/send`
- Header: `Authorization: Bearer <access_token>`
- Body: `{ "raw": "<RFC 2822 message, base64url encoded>" }`
- `me` is the signed-in user, so the mail is sent **from that Google account**.
- Required scope: `https://www.googleapis.com/auth/gmail.send` (the narrowest scope that can send; it cannot read the mailbox).

### 6.3 Practical details and limits
- **The From address** is the authenticated account (or one of its configured "Send mail as" aliases). You cannot send as an arbitrary address.
- **Granular consent**: Google lets users untick individual permissions on the consent screen. `auth.hasGmailSendScope` tells you whether `gmail.send` was granted; `GmailService` checks it and throws `scopeNotGranted` otherwise.
- **Non-ASCII subjects** are encoded with RFC 2047 (`=?UTF-8?B?...?=`), and the body is sent as base64 UTF-8, so accents and emoji work.
- **Attachments**: build a `multipart/mixed` MIME message (a text part plus one part per file, each base64 encoded with `Content-Disposition: attachment; filename="..."`), then base64url encode it exactly as the current code does. Keep the total message under roughly 35 MB (base64 inflates size by about a third).
- **Sending quotas**: consumer Gmail accounts are limited to about 500 recipients/day, Workspace accounts to about 2,000/day (figures change, so check the current Gmail sending limits).
- **Bulk or marketing email** is not what this is for; use a transactional email provider for that.
- Messages sent this way appear in the user's **Sent** folder.
- If the data you email is sensitive (for example patient data), remember that Gmail is not end-to-end encrypted, and check the privacy rules that apply to you.

### 6.4 Common errors

| HTTP | Meaning | What to do |
|---|---|---|
| 400 | Malformed message (bad recipient, bad MIME) | Validate addresses; check headers. |
| 401 | Invalid/expired access token | `freshAccessToken()` refreshes it; if it still fails, sign in again. |
| 403 `insufficientPermissions` | `gmail.send` scope not granted | Sign in again and accept the permission. |
| 403 `accessNotConfigured` | Gmail API not enabled in the project | Enable it (section 2.2). |
| 403 `access_denied` at sign-in | Account not in Test users, or app unverified | Add as test user, or publish/verify. |
| 429 | Rate limit | Retry with exponential backoff. |

---

## 7. Troubleshooting

- **Browser opens but never returns to the app**: the sandbox is missing *Incoming Connections (Server)*, or a firewall blocks the loopback port.
- **App seems to hang at launch**: while the launch check waits for the browser, the app shows "Checking your Google session…" for up to 120 seconds (use **Cancel** to stop it). If it then falls back to the login screen with a message, the check was inconclusive (see section 1). The interactive sign-in has no timeout, so a missing `network.server` entitlement makes it wait forever on "Waiting for the browser…". Check the entitlements first (section 3.3), then the Xcode console.
- **iOS client: browser answers but the app does not come back / hangs on "Waiting for the browser…"**: the URL scheme is missing from Info.plist or does not match the client ID (reversed, with the `com.googleusercontent.apps.` prefix), or the key `GoogleIOSClientID` is empty.
- **iOS client: the redirect opens another copy of the app**: macOS routes a custom URL scheme to one registered copy of the app. If you have several (a build in DerivedData, one in /Applications, an older archive), the browser may open the wrong one. Delete the extra copies and run the one you want from Xcode once.
- **iOS client: "Open WOA?" prompt at every launch**: it is the browser's confirmation for custom-scheme links. Chrome offers an "always allow" checkbox; Safari can ask each time. This is the main usability difference from the Desktop client.
- **Login screen after switching `googleAuthUseIOSClient`**: expected, the stored session belongs to the other client type (see section 2.6).
- **Login screen at every launch with `interaction_required` in the log**: this was the symptom of using `prompt=none`, which the app no longer does. If you see it again, check that the launch check is not passing a `prompt` value.
- **"Error 400: invalid_request" / redirect issues**: the OAuth client type is not **Desktop app**.
- **"This app isn't verified"**: expected in Testing or unverified production; users click *Advanced → Continue*. Add them as test users.
- **Login screen at every launch although the browser is signed in**: the launch check is failing. Common causes are several Google accounts in the browser that Google cannot pick silently, a different default browser profile, or a browser that blocks the redirect to `127.0.0.1`.
- **Re-login every 7 days**: the consent screen is in *Testing* (see 2.4).
- **`GoogleClientID` errors at launch**: Info.plist keys are missing or the `.xcconfig` variables are not expanded.
- **Keychain prompts repeatedly during development**: re-signing the app with a different certificate changes access to its Keychain items; click *Always Allow* or sign consistently.

---

## 8. Checklist

- [ ] Google Cloud project created
- [ ] Gmail API enabled
- [ ] Consent screen configured, scopes added, test users added
- [ ] OAuth client of type **Desktop app** created
- [ ] `GoogleClientID` / `GoogleClientSecret` added to Info.plist (kept out of git)
- [ ] AppAuth Swift package added
- [ ] Sandbox network client + server entitlements enabled (if sandboxed)
- [ ] All Swift files added; `AppLogger.warning(_:)` signature matches
- [ ] `AuthGate` wraps the root view; `GoogleLogoutButton` placed in the UI
- [ ] `googleAuthEnabled` set to `true` in the app settings
- [ ] Tested: first sign-in, relaunch (silent check), browser logout then relaunch, offline relaunch, logout button, sending an email
