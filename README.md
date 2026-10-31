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
2. Optionally select **Copy selected database into Application Support**. When unchecked, WOA uses the selected database file directly and asks you to grant access to its containing folder so SQLite can manage sibling journal files; when checked, WOA uses an app-owned copy. The checkbox is unchecked by default and is not saved separately.
3. Click **Import Database**. The selected database is validated against the core tables (`paziente`, `consulto`, `esame`, `trattamento`, `valutazione`, `anamnesi_remota`, `anamnesi_prossima`), and a summary of its tables is shown.

Subsequent launches use the saved active database path and connect automatically. For a database used directly, WOA saves a security-scoped bookmark for the selected containing folder and restores that permission. The folder grant is limited to the folder the user chooses, not the entire home directory. SQLite may create or check optional journal sidecars beside a directly used database; the user does not need to supply a pre-existing `.db-wal` file. If macOS denies access to required sidecars, choose the copy option so SQLite can manage them in Application Support.

## App Sandbox

App Sandbox is enabled ([src/WOA/Resources/WOA.entitlements](src/WOA/Resources/WOA.entitlements)) with a single entitlement:

- `com.apple.security.files.user-selected.read-write` — required so the user can pick a database file via `NSOpenPanel`.

The application's own data (optional database copy, configuration, logs) is stored under:

```swift
FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
```

The app does not receive unrestricted filesystem access. Direct access uses a security-scoped bookmark for the user-approved database folder; the copy option stores SQLite's database and journal files in Application Support. See [database folder permissions](docs/database-folder-permissions.md) for details.

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

### Commnand line

```bash
./build-release.sh
```

This builds the `WOA` scheme in the `Release` configuration and writes output to `build-release.log`.

### Xcode
Here’s a **minimal, clean Markdown documentation** you can drop into your repo.  
It covers only the essential steps: **build Release** and **locate the `.app` bundle**.

---

#### 1. Switch Scheme to Release
To ensure Xcode builds your app in **Release** mode:

1. Open **Product → Scheme → Edit Scheme…**  
2. Select **Run** in the left sidebar  
3. Set **Build Configuration = Release**  
4. Close the window

---

#### 2. Build the App
Run a Release build:

- **Product → Build**

Xcode now produces a Release `.app` bundle.

---

#### 3. Locate the Release Build Folder
Use Xcode’s built‑in navigation:

1. Open **Product → Show Build Folder**  
2. Finder opens inside your project’s build directory  
3. Navigate to:

```
Build/Products/Release/
```

Inside this folder you will find:

```
YourAppName.app
```

This is the distributable macOS application bundle.

---

#### 4. Full Path (for reference)
Xcode stores build products inside DerivedData:

```
~/Library/Developer/Xcode/DerivedData/<ProjectName>-<Hash>/Build/Products/Release/YourAppName.app
```

You can open the DerivedData root via:

- **Xcode → Settings → Locations → Derived Data → arrow icon**

---


## Troubleshooting

- **Sandbox denials in Console.app**: verify the entitlements file is attached to the target's `CODE_SIGN_ENTITLEMENTS` build setting.
- **"Database schema not recognized"**: the selected file is missing one or more of the core tables listed above.
- **Signing errors**: select a valid development team in **Signing & Capabilities**, or switch `CODE_SIGN_STYLE` to `Automatic`.
