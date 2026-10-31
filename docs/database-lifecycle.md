# Database selection, storage, and App Sandbox access

WOA requires a compatible SQLite database before database-backed features are
enabled. This guide describes first-run selection, direct and copied database
modes, persistent sandbox access, the application data locations, and recovery.

## Select a database

On first launch, the database management screen shows **Database Configuration
Required**.

1. Choose **Browse Database File** and select a `.db`, `.sqlite`, or `.sqlite3`
   file.
2. Choose whether to enable **Copy selected database into Application
   Support**. It is unchecked by default and is a one-time selection, not a
   saved preference.
3. Choose **Import Database**.

WOA requires these core tables: `paziente`, `consulto`, `esame`,
`trattamento`, `valutazione`, `anamnesi_remota`, and `anamnesi_prossima`.
[`data/woa-schema.sql`](../data/woa-schema.sql) is the schema reference.

### Direct mode (default)

With copying disabled, WOA operates on the original selected database in place.
It asks the user to select the database's immediate containing folder and
checks that the selected folder is correct. If folder selection is cancelled,
the current import does not save a new database configuration.

WOA stores a security-scoped bookmark for that folder with the database
connection settings. The bookmark authorizes access to that selected folder;
it does not grant general access to the user's home directory. WOA restores the
folder access before running SQLite on later launches and refreshes the bookmark
if macOS reports it as stale. If a bookmark resolves to a moved folder, WOA can
update the saved database path. If access is revoked, the database is missing,
or the bookmark cannot be resolved, WOA reports the problem and offers
recovery.

Folder access is needed because SQLite may create or open sibling journal
files, commonly `-wal` and `-shm`. The user selects only the database itself;
pre-existing sidecars are not required. If SQLite cannot use the external
folder, grant access again or copy the database into Application Support.

### Copy mode

With copying enabled, WOA copies the selected database to its app-owned
location, then uses that copy:

```text
Application Support/WOA/database/woa.db
```

The original selected file is not the active database after copying. WOA does
not need a persistent bookmark for subsequent access to the app-owned copy.
SQLite and its journal files operate inside Application Support.

Copy mode also exists as a recovery action when migrations or SQLite access
fail for an external database. **Copy to Application Support and Retry** changes
the active database to the managed copy; it does not move or rewrite the
original file.

## Import and connection lifecycle

1. WOA opens the system file picker and temporarily accesses the selected file.
2. In direct mode, WOA authorizes the containing folder and creates a bookmark.
   In copy mode, it installs the database in Application Support.
3. WOA stores the database path and, for direct mode, the folder bookmark in
   its configuration file.
4. WOA runs pending bundled application migrations against the selected active
   database. In copy mode, installation attempts to normalize the copy and
   checks for the expected core tables before application migrations run.
5. WOA validates the schema, reads table names and row counts, and marks the
   connection ready.
6. The import summary appears. Choose **Continue** to reach the connected
   launch screen.

On later launches, WOA loads the saved configuration, restores external folder
access when needed, applies pending migrations, validates the database, and
then exposes database-backed features. A migration failure leaves the
connection unavailable until recovery succeeds. Available actions include
retrying migrations, granting folder access, copying an external database, or
choosing another database. See [Database migrations](migrations.md) for the
transaction and failure behavior.

The connected database status panel provides **Re-select Database**. After
confirmation, WOA clears the active database configuration and returns to the
selection screen.

## App Sandbox and entitlements

App Sandbox is enabled for the WOA target. The target's
`CODE_SIGN_ENTITLEMENTS` build setting points to
[`src/WOA/Resources/WOA.entitlements`](../src/WOA/Resources/WOA.entitlements),
which contains:

- `com.apple.security.app-sandbox` — enables the sandbox.
- `com.apple.security.files.user-selected.read-write` — allows user-mediated
  read/write access to the selected database file.

The file-selection entitlement alone is not a permanent general filesystem
grant. Direct mode persists the user's folder authorization using a
security-scoped bookmark. Copy mode uses app-owned storage instead. The app
uses the macOS `NSOpenPanel` to select database files and folders.

## Application-owned storage

WOA obtains the Application Support directory using
`FileManager`'s `.applicationSupportDirectory` URL and creates an app-specific
`WOA` directory. Its current layout is:

| Purpose | Location under `Application Support/WOA` |
|---|---|
| Installed SQLite database | `database/woa.db` |
| Serialized application settings | `configuration/app-settings.json` |
| Log file | `logs/app.log` |
| Cache area (created when requested) | `cache/` |

Database connection details and the external-folder bookmark are serialized in
`app-settings.json`; the current settings model also stores the log-level and
theme settings there. SQLite data, logs, and application files belong in
Application Support, not `UserDefaults`. Use `UserDefaults` only for small
preferences if a future feature explicitly adopts it.

Avoid moving the app-owned database into Documents, Downloads, or another
user-selected directory. Security-scoped bookmarks are for external resources
the user selects, such as a directly used database folder—not for WOA's own
Application Support files.

## Related implementation

- [`DatabaseManagementViewModel`](../src/WOA/ViewModels/DatabaseManagementViewModel.swift)
  coordinates selection, bookmark restoration, migration, and recovery.
- [`DatabaseInstaller`](../src/WOA/Utils/DatabaseInstaller.swift) installs the
  copy-mode database.
- [`AppPaths`](../src/WOA/Utils/AppPaths.swift) defines app-owned storage URLs.
- [`DatabaseValidator`](../src/WOA/Utils/DatabaseValidator.swift) checks the
  required schema tables.
- [`WOA.entitlements`](../src/WOA/Resources/WOA.entitlements) defines the
  sandbox capabilities.
