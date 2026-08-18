# WOA

A macOS SwiftUI application with a sandboxed, user-selected SQLite database.

## System Requirements

- macOS 13.0 or later
- Xcode 15.0 or later

## Xcode Setup

1. Open `src/WOA.xcodeproj` in Xcode.
2. Select the `WOA` scheme.
3. In the target's **Signing & Capabilities** tab, choose your development team.
4. Build and run (`Cmd+R`).

## First Run: Database Selection

On first launch, no database is configured. The app shows a **Database Configuration Required** screen:

1. Click **Browse Database File** and select a SQLite database (e.g. [data/woa-schema.sql](data/woa-schema.sql) after creating a `.db` from it).
2. Click **Import Database**. The file is validated against the core tables (`paziente`, `consulto`, `esame`, `trattamento`, `valutazione`, `anamnesi_remota`, `anamnesi_prossima`).
3. On success, the database is copied into the app's sandboxed Application Support directory and a summary of imported tables is shown.

Subsequent launches read the stored configuration and connect automatically.

## App Sandbox

App Sandbox is enabled ([src/WOA/Resources/WOA.entitlements](src/WOA/Resources/WOA.entitlements)) with a single entitlement:

- `com.apple.security.files.user-selected.read-write` — required so the user can pick a database file via `NSOpenPanel`.

The application's own data (database copy, configuration, logs) is stored under:

```swift
FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
```

No entitlements are granted for unrestricted access to Documents, Downloads, or the user's home directory.

## Project Structure

```text
src/WOA/
├── WOA.swift
├── Models/
├── ViewModels/
├── Views/
├── Services/
├── Repositories/
├── Utils/
└── Resources/
```

Add new files to the folder matching their architectural layer (View, ViewModel, Service, Repository, Utils/Storage), then add them to the `WOA` target in Xcode so they're included in the build.

## Building for Release

```bash
./build-release.sh
```

This builds the `WOA` scheme in the `Release` configuration and writes output to `build-release.log`.

## Troubleshooting

- **Sandbox denials in Console.app**: verify the entitlements file is attached to the target's `CODE_SIGN_ENTITLEMENTS` build setting.
- **"Database schema not recognized"**: the selected file is missing one or more of the core tables listed above.
- **Signing errors**: select a valid development team in **Signing & Capabilities**, or switch `CODE_SIGN_STYLE` to `Automatic`.
