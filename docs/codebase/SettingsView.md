Read 

Read 

## `SettingsView` — Functional Overview

`SettingsView` is the app's **single main window/root view** (per the navigation architecture rule): it's the entry point, and every feature (patient search, patient detail, add patient, consultations, remote history) loads inline inside it rather than in separate windows or sheets.

Functionally it has two states:

1. **Not configured** — no valid database yet. Shows "Database Configuration Required" and embeds DatabaseSelectorView so the user can pick/import a database file.
2. **Configured** — renders `LaunchScreenView`, which shows the connection status and table list beside `ApplicationSettingsView`. The settings panel includes the full Application Support path to the JSON settings file and labeled values for every persisted setting. The toolbar exposes **Home**, **Back**, and **Patients Search**.

Between those, while `selectorViewModel.didImportSuccessfully` is true, it shows `TableStatusView` (post-import summary) before returning to the connected view. Database reselection is available beneath the connected table list and requires confirmation before clearing the current configuration.

## Code Perspective

**State owned by the view** (`SettingsView.swift`):
- `settingsViewModel: SettingsViewModel` (`@StateObject`) — connection/config state, table stats.
- `selectorViewModel: DatabaseSelectorViewModel` (`@StateObject`) — drives the database-selection/import flow.
- `dataChangeCoordinator: DataChangeCoordinator` (`@StateObject`) — the app-scoped mutation-event bus, created once here and passed down to every mutating child view (`AddPatientView`, `PatientDetailView`, `AddConsultationView`, `AddRemoteHistoryView`).
- `navigationPath: [NavigationRoute]` — a private, typed, `Hashable` route enum driving a single `NavigationStack`. This is the concrete-route pattern required by the navigation guardrails (no ambiguous `NavigationPath`).

**Navigation mechanics:**
- `NavigationStack(path: $navigationPath)` with `.navigationDestination(for: NavigationRoute.self)` maps each route case to its destination view, injecting `databaseFileURL`/`patientID`/etc. as typed payloads.
- Child views receive plain closures (`onCancel`, `onSuccess`, `onOpenDetails`, `onDeleted`, etc.) that only mutate `navigationPath` — i.e., navigation callbacks are purely for navigation, never for data refresh (per the 04.1 state-management plan). Data refresh instead flows through `dataChangeCoordinator`, which mutating view models publish to after a successful repository call, and detail/list view models subscribe to.
- Toolbar buttons: **Home** clears the path, **Back** pops one route, and **Patients Search** pushes `.patientsSearch` (disabled until configured). `LaunchScreenView` owns the connected table/settings composition, while the table panel's confirmed **Re-select Database** action clears the path and calls `settingsViewModel.resetConfiguration()`.

**Lifecycle:**
- `.onAppear` calls `settingsViewModel.loadSettings()` and clears the path if not configured.
- `.onChange(of: settingsViewModel.isConfigured)` also clears the path whenever configuration is lost (e.g. after reset), so the view can't be left navigated into a stale detail screen.

## Storage and Sandbox Boundaries

- Application-owned settings, logs, cache, and SQLite data remain under the app's Application Support directory.
- UserDefaults is reserved for small preferences such as theme, language, window geometry, and selected tabs; it is not used for settings files, databases, logs, or documents.
- Internal application paths are built with `URL` APIs rather than string concatenation.
- `NSOpenPanel` is used for user-selected database files. Security-scoped bookmarks are reserved for external user-selected resources, and `NSSavePanel` is used for exports when needed.

**`SettingsViewModel`** (`SettingsViewModel.swift`) is the `@MainActor` service-calling layer: `loadSettings()` reads `ConfigurationService`, then asynchronously validates the DB (`testDatabaseConnection()` via `DatabaseValidator`) and loads table stats (`refreshTableStats()` via `TableRepository`). `resetConfiguration()` clears persisted connection info. No SQL or file I/O happens directly in the view — it all goes through the ViewModel → Service/Repository layers, consistent with the architecture rules.