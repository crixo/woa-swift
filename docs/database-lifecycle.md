# Database selection, storage, and App Sandbox access

WOA needs a compatible SQLite database before database-backed features can be
used. The reference schema is [`data/woa-schema.sql`](../data/woa-schema.sql).
The validator requires `paziente`, `consulto`, `esame`, `trattamento`,
`valutazione`, `anamnesi_remota`, and `anamnesi_prossima`.

## Select or import a database

On first use, choose a `.db`, `.sqlite`, or `.sqlite3` file with the database
picker. The **Copy selected database into Application Support** option is
unchecked by default and applies to that import:

- **Direct mode:** WOA operates on the selected database in place. It asks for
  the immediate containing folder and stores a security-scoped bookmark for
  that folder.
- **Copy mode:** WOA copies the selected database to its app-owned database
  location and then uses that copy. The original is unchanged and no persistent
  bookmark is needed for the copy.

Direct folder access allows SQLite to create/open sibling journal files such
as `-wal` and `-shm`; selecting the database file alone does not grant general
filesystem access. WOA restores the bookmark on later launches and can refresh
a stale bookmark. If access is revoked or the database is unavailable, the
database screen offers recovery, including granting access again, copying an
external database, or choosing another file.

The migration service applies bundled migrations before database validation
marks the connection ready. See [Migrations](migrations.md) for failure and
retry behavior.

## Sandbox and external files

The WOA target enables App Sandbox and user-selected read/write access. The
database picker uses macOS `NSOpenPanel`. The bookmark authorizes the
user-selected external database folder; it is not a bookmark for application
data. See [`WOA.entitlements`](../src/WOA/Resources/WOA.entitlements).

## Application-owned storage

WOA creates an app-specific directory below the system Application Support
directory:

| Data | Location under `Application Support/WOA` |
|---|---|
| Managed SQLite copy | `database/woa.db` |
| JSON configuration | `configuration/app-settings.json` |
| Log file | `logs/app.log` |
| Cache directory | `cache/` |

`AppPaths` builds these locations with URL APIs. The settings file contains the
database path/bookmark, display preferences, Google authentication options,
and recent-patient limit. Google OAuth tokens are stored separately in the
macOS Keychain. Google startup-check flags use `UserDefaults`; in general,
`UserDefaults` is for small preferences, while application data, configuration,
logs, and the managed SQLite database belong in Application Support. A
security-scoped bookmark is used only for the external database folder the
user selected.

## Important current startup limitation

`WOA.init()` calls `load()` on an `AppSettingsStore`, then assigns a second,
fresh store to the same state property. The root view receives this new store,
so saved database configuration and settings are not reliably restored at
startup. The database-selection and bookmark flows are implemented, but
relaunch restoration is currently blocked by this initialization defect. Do not
assume an existing selection will survive relaunch until the code is corrected.

## Relevant implementation

- [`DatabaseManagementViewModel`](../src/WOA/ViewModels/DatabaseManagementViewModel.swift)
  coordinates selection, bookmark access, migration, and recovery.
- [`DatabaseInstaller`](../src/WOA/Utils/DatabaseInstaller.swift) installs the
  copy-mode database.
- [`AppPaths`](../src/WOA/Utils/AppPaths.swift) defines app-owned storage URLs.
- [`DatabaseValidator`](../src/WOA/Utils/DatabaseValidator.swift) checks the
  required schema tables.
- [`ConfigurationService`](../src/WOA/Services/ConfigurationService.swift)
  serializes settings as JSON.
