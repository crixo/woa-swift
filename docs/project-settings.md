# Xcode project and application settings

This guide describes the checked-in WOA target configuration in
[`src/WOA.xcodeproj/project.pbxproj`](../src/WOA.xcodeproj/project.pbxproj),
[`Info.plist`](../src/WOA/Resources/Info.plist), and
[`WOA.entitlements`](../src/WOA/Resources/WOA.entitlements).

## Target configuration

- Shared scheme: `WOA`.
- macOS deployment target: 14.6.
- Bundle identifier: `com.woa.application`.
- Marketing and build versions: `MARKETING_VERSION` and
  `CURRENT_PROJECT_VERSION` in the project file; the physical plist refers to
  these settings.
- Physical `Info.plist`: `src/WOA/Resources/Info.plist`.
- Entitlements: `src/WOA/Resources/WOA.entitlements`.
- Swift packages: AppAuth (minimum 3.0.0, up to next major) and Sparkle
  (minimum 2.10.1, up to next major).
- Shared scheme is committed at
  `src/WOA.xcodeproj/xcshareddata/xcschemes/WOA.xcscheme`.

## Local OAuth configuration

The project references `src/Config/Secrets.xcconfig`, but the file is absent
from the repository and ignored by `.gitignore`. If Xcode reports that this
project configuration is missing, create the local file; set
`GOOGLE_IOS_CLIENT_ID` there when configuring the Google iOS client. The
`Info.plist` URL scheme is currently literal and must match the reversed OAuth
client ID. Desktop OAuth is not configured in the plist: the
`GoogleClientID` and `GoogleClientSecret` keys are absent.

Do not commit OAuth private credentials or local configuration. Any values
substituted into the built Info.plist are visible in the app bundle.

## App Sandbox

The entitlements file enables App Sandbox, user-selected read/write files,
network client/server access, and Sparkle installer-launcher Mach lookup names.
The `CODE_SIGN_ENTITLEMENTS` build setting points to this file.

## Application settings and storage

`ConfigurationService` serializes `AppSettings` as JSON at
`Application Support/WOA/configuration/app-settings.json`. It includes database
connection details and bookmark, theme, log level, Google auth options, and
the recent-patient display limit. The limit defaults to 5 and must be positive
when saved. Google tokens are stored in Keychain, not in this settings file.

### Settings initialization

At app launch, `WOA.init()` creates an `AppSettingsStore` instance and calls
`load()` to restore persisted settings from disk. The store is then connected
to the root view through the `@StateObject` property wrapper. If no settings
file exists, the store uses `AppSettings.default`.

## Inspect build settings

On macOS, inspect the resolved settings with:

```bash
xcodebuild \
  -project src/WOA.xcodeproj \
  -scheme WOA \
  -showBuildSettings
```

After building, inspect the merged runtime plist inside
`WOA.app/Contents/Info.plist`. It is the actual source for Sparkle and OAuth
configuration at runtime.
