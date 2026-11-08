# Sparkle

## Download
Download the tools
```bash
mkdir -p ~/sparkle-tools && cd ~/sparkle-tools
gh release download --repo sparkle-project/Sparkle --pattern 'Sparkle-*.tar.xz'
tar -xf Sparkle-*.tar.xz
ls bin    # generate_appcast  generate_keys  sign_update
```
Without gh, download the Sparkle-2.x.x.tar.xz asset from https://github.com/sparkle-project/Sparkle/releases and extract it.

If macOS blocks a tool on first run, remove the quarantine flag:
```bash
xattr -dr com.apple.quarantine ~/sparkle-tools
```

## Keys
1. Parameters
None are required. Run it with no arguments:
```bash
~/sparkle-tools/bin/generate_keys
```

2. Private key in the Keychain
Yes. It saves the private key as an item in your login Keychain (named “Private key for signing Sparkle updates”, account ed25519). macOS may ask you to allow access. Choose “Always Allow” or “Allow”.

If a key already exists, running it again does not create a new one. It prints the existing public key, so it’s safe to re-run if you lose the console output. generate_keys -p prints only the public key.

Caveat: the key exists only in that Keychain, on that Mac. If you lose the Mac or reinstall macOS without a backup, you can’t sign updates any more. Export it once:
```bash
~/sparkle-tools/bin/generate_keys -x ~/woa-sparkle-private-key
```

Store that file somewhere safe, such as a password manager. Don’t commit it to the repo.

3. Public key into the config

Te tool prints a line like:

```
A pre-existing signing key was found / A key has been generated and saved in your keychain.
Add the following to your Info.plist:

    <key>SUPublicEDKey</key>
    <string>abc123...=</string>
```

Copy the string value into SUPublicEDKey in src/WOA/Resources/Info.plist, replacing REPLACE_WITH_PUBLIC_ED_KEY_FROM_generate_keys. My script checks that it’s a valid 44-character key.


The standard answer for a Swift desktop app (macOS) is **Sparkle**, the de facto auto-update framework. It handles checking, downloading, signature verification, installing, and relaunching. It reads an "appcast" XML feed, and you can host that feed on GitHub.

## Option 1: Sparkle (recommended)

**1. Add the package.** In Xcode: File → Add Package Dependencies → `https://github.com/sparkle-project/Sparkle`

**2. Generate signing keys** (once). Run Sparkle's `generate_keys` tool (in the package artifacts, `bin/generate_keys`). It stores the private key in your Keychain and prints the public key.

**3. Configure Info.plist:**
```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/YOURUSER/YOURREPO/main/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY</string>
<key>SUEnableAutomaticChecks</key>
<true/>
```

**4. Start the updater in code.**

SwiftUI:
```swift
import SwiftUI
import Sparkle

@main
struct MyApp: App {
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup { ContentView() }
            .commands {
                CommandGroup(after: .appInfo) {
                    Button("Check for Updates…") {
                        updaterController.checkForUpdates(nil)
                    }
                }
            }
    }
}
```

**5. Publish a release.**
1. Build, notarize, and zip your `.app` (or make a DMG).
2. Run `generate_appcast ./releases_folder`. It signs the archives and produces `appcast.xml`.
3. Create a GitHub Release and attach the zip/DMG.
4. Make sure the appcast's `<enclosure url="...">` points at the GitHub release asset URL, and commit `appcast.xml` to the repo.

You can automate step 5 with GitHub Actions, building on tag push, signing with the private key stored as a secret (`generate_appcast --ed-key-file`), uploading the asset, and committing the updated appcast.

**Requirements:** the app should be code-signed with a Developer ID and notarized. If it's sandboxed, you need extra XPC entitlements (see Sparkle's sandboxing docs).

## Option 2: DIY with the GitHub Releases API

Fine if you only want a "new version available" notification, though installing the update yourself is harder to do safely.

```swift
struct Release: Decodable {
    let tag_name: String
    let html_url: URL
    let assets: [Asset]
    struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }
}

func checkForUpdate() async throws {
    let url = URL(string: "https://api.github.com/repos/USER/REPO/releases/latest")!
    var req = URLRequest(url: url)
    req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    let (data, _) = try await URLSession.shared.data(for: req)
    let release = try JSONDecoder().decode(Release.self, from: data)

    let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

    if latest.compare(current, options: .numeric) == .orderedDescending {
        // Show an alert; open release.html_url or download the asset
    }
}
```

Call it at launch and on a timer (e.g. every 24h). Notes:
- The unauthenticated API is rate-limited to 60 requests/hour per IP, which is plenty for this.
- Replacing the running app yourself means downloading, verifying a signature or checksum, swapping the bundle, and relaunching via a helper. That is exactly what Sparkle does, and it's easy to get wrong, so I'd use it unless you only need notifications.

## Which to pick

- **Want true auto-install:** Sparkle.
- **Just want to notify and open the release page:** the DIY approach is about 30 lines.

If you tell me whether the app is SwiftUI or AppKit, sandboxed or not, and how you distribute it (zip, DMG, App Store), I can tailor the setup. I can also write the GitHub Actions workflow that builds, signs, and publishes the appcast on each release.

## Why updates start without the button
Two things start the updater, and neither involves the button:

startingUpdater: true in WOA.init() starts Sparkle’s updater as the app launches.
SUEnableAutomaticChecks = true in Info.plist tells it to check the appcast on its own: shortly after launch, then every SUScheduledCheckInterval (86400 seconds, once a day).

The button only does a manual check on demand. It also shows a result even when there’s no update (“You’re up to date”), while automatic checks stay silent unless an update exists.

Automatic checks only look for updates and prompt you. Nothing downloads or installs silently unless you also set SUAutomaticallyUpdate to true, and I didn’t.