# Database selection and access modes

WOA requires a SQLite database before it can continue to the connected launch
screen. The database selector offers two ways to use the chosen `.db` file:

1. **Use the selected file directly** — the default. WOA operates on the
   original file in its current location.
2. **Copy the selected database into Application Support** — WOA installs and
   operates on an app-managed copy.

The checkbox choice is transient; it is not saved as a separate preference.
What is persisted is the resulting database path and, for direct external
databases, the security-scoped bookmark needed to regain access later.

## What a security-scoped bookmark means

macOS App Sandbox restricts which files an app can access. When the user
selects an external database, the file panel grants access for the current
selection flow. Direct mode also asks the user to select the database's
containing folder. WOA saves a **security-scoped bookmark** for that folder in
the database connection settings.

The bookmark is opaque macOS bookmark data, not just a path and not a copy of
the database. It records the user's authorization to the selected folder so
WOA can resolve it on later launches and start a security-scoped access
session before SQLite works with the database. Folder-level access is needed
because SQLite may create or open sibling journal files such as `-wal` and
`-shm`. The bookmark does not grant unrestricted access to the user's home
directory. WOA stops the access session when it no longer needs it.

In the current settings model, `securityScopedDirectoryBookmark` is the
bookmark used for direct-mode folder access. The older `securityScopedBookmark`
field can contain a bookmark to an individual database file from an earlier
configuration. WOA continues to recognize that legacy value and upgrades it
to a containing-folder bookmark when resolving the existing configuration.
Copy mode stores a path inside Application Support and does not need an
external security-scoped bookmark.

Bookmarks can become stale, or access can fail if the user moves the database,
changes permissions, or revokes access. WOA attempts to resolve and refresh
stale bookmarks. If access cannot be restored, the connection flow reports
the problem and lets the user grant folder access, copy the database, or
select another database.

## Selection and launch flow

### 1. Mandatory database selection

If no database is configured, the database management area shows
**Database Configuration Required** and the selector. The user chooses a
`.db`, `.sqlite`, or `.sqlite3` file with the system file panel. The selector's
copy checkbox is unchecked by default:

- **Unchecked — direct mode:** WOA will use the selected database at its
  existing location and ask the user to authorize its containing folder.
- **Checked — copy mode:** WOA will copy the selected database to Application
  Support and use that copy.

Pressing **Import Database** begins the selected workflow. In direct mode,
WOA asks the user to select the immediate containing folder and verifies that
it is the correct folder. If the user cancels this folder authorization, the
selection flow remains available without saving a database configuration.

### 2. Install or use the selected file

In copy mode, `DatabaseInstaller` copies the selected database into
Application Support. It normalizes the installed copy where possible and
validates its schema. Any journal cleanup used during normalization is
limited to the app-managed copy; validation of the user's original database
does not delete its SQLite sidecars.

In direct mode, WOA saves the external file path and the folder bookmark,
then accesses that original file under the user's authorization. It does not
require a pre-existing WAL sidecar. SQLite may create or use journal sidecars
next to the database; if sandbox permissions prevent this, the user can grant
folder access or switch to copy mode.

### 3. Apply pending database migrations and validate

After choosing the database location, WOA applies any pending bundled
application database migrations to the database that will actually be used.
This happens in either mode: migrations update the database itself, not just
the copy workflow. WOA then validates that the expected core tables are
present and reads table names and record counts.

If migration fails, WOA blocks continuation and presents migration recovery
actions, as applicable:

- Retry migrations.
- Grant access to the database's containing folder and retry.
- Copy the active database into Application Support and retry.
- Choose another database.

The copy-and-retry action changes the configured database to the managed
Application Support copy. It does not silently change the original external
file's location.

### 4. Confirm and continue to the launch screen

After a successful initial selection, WOA shows a one-time **Database Import
Successful** status with the table names and record counts. Press **Continue**
to finish the selection flow. WOA reloads the saved configuration and displays
the connected launch screen.

On later launches, WOA restores the configured database path. For a direct
external database it resolves the folder bookmark and starts security-scoped
access before running migrations, validation, or queries. For a database in
Application Support, no external bookmark is needed. WOA applies any newly
pending migrations, validates the database, and then shows the launch screen
with its table status and migration information.

### 5. Re-select a database

The connected launch screen exposes **Re-select Database** in its database
table-status panel. The action asks for confirmation because it clears the
current database connection. After confirmation, WOA returns to the mandatory
selector; the user can choose a different database and select either direct
or copy mode again.

The selector also remains available through the **Choose Another Database**
action on the migration-failure screen. Existing Application Support database
configurations remain supported.

## Storage and implementation notes

- Application-owned data, including an installed SQLite database and
  configuration, belongs in Application Support. UserDefaults is reserved for
  small preferences, not database files or bookmarks.
- Direct-mode databases are external user-selected resources. Their access
  authorization is represented by a security-scoped bookmark.
- The selector and its state are managed by
  [`DatabaseManagementViewModel`](../src/WOA/ViewModels/DatabaseManagementViewModel.swift);
  [`DatabaseSelectorView`](../src/WOA/Views/DatabaseSelectorView.swift) presents
  the two choices.
- [`DatabaseInstaller`](../src/WOA/Utils/DatabaseInstaller.swift) handles
  copy-mode installation, and
  [`DatabaseMigrationService`](../src/WOA/Services/DatabaseMigrationService.swift)
  applies pending application migrations to the active database.
- [`DatabaseManagementView`](../src/WOA/Views/DatabaseManagementView.swift)
  selects the mandatory, migration-recovery, post-selection, or connected
  screen based on database state. The connected table panel is presented by
  [`LaunchScreenView`](../src/WOA/Views/LaunchScreenView.swift).

For further detail on the sandbox permission requirement, see
[`database-folder-permissions.md`](./database-folder-permissions.md).
