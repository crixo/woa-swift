# Database migrations

WOA runs bundled SQLite migrations before it connects and exposes a configured
database to the rest of the application. This applies both to a database already
configured on a later launch and to a database newly imported by the user.

## Migration bundle and release packaging

Migration scripts live in [`data/migrations`](../data/migrations/). The Xcode
project references that directory as a folder resource: the `migrations`
`PBXFileReference` points to `../../data/migrations`, and its build file is
included in the WOA target's Resources build phase in
[`project.pbxproj`](../src/WOA.xcodeproj/project.pbxproj). Xcode copies the
directory, including its SQL files, into the built app as
`WOA.app/Contents/Resources/migrations`. At runtime,
[`DatabaseMigrationService`](../src/WOA/Services/DatabaseMigrationService.swift)
locates that resource through `Bundle.main`; it does not read migration scripts
from the working tree or a user-selected location.

The scripts do not create this bundle themselves:

- [`build-release.sh`](../build-and-release/build-release.sh) runs
  `xcodebuild build` using the Release configuration. It does not separately
  generate or copy migrations; the Xcode Resources build phase handles that.
- [`swift-build-tag-release.sh`](../build-and-release/swift-build-tag-release.sh)
  creates an Xcode archive, copies or exports the resulting `.app`, then creates
  an application ZIP and DMG. Those packages contain the same app bundle and
  its Xcode-bundled `Contents/Resources/migrations` directory.
- [`codemagic.yaml`](../codemagic.yaml) has a standard release workflow that
  archives the app, copies it from the archive, and creates a DMG. Its other
  release workflow invokes `./build_release.sh`; that path/name does not match
  the checked-in [`build-release.sh`](../build-and-release/build-release.sh)
  location, so verify that workflow's script path before relying on it.

If `data/migrations` contains no `.sql` files, the app still creates the
migration ledger but has no scripts to apply.

## Adding a migration

Add a forward-only `.sql` file with a unique numeric prefix and `_` or `-`
separator, for example `001_add_example_index.sql` or
`002-add-example-column.sql`. The prefix is the migration ID and determines
execution order numerically, not lexicographically. IDs must be unique even if
their spelling differs (for example, `1_...sql` and `001-...sql` collide).

Treat an applied migration as immutable: do not rename, edit, or reuse its ID.
Add a new migration to make a later schema change. Do not create or alter the
`woa_migration` ledger in a migration script.

## Runtime process

1. **Prepare the database.** When importing, WOA copies the selected database
   into Application Support, normalizes SQLite journal state, and checks that
   the expected core tables are present. A later launch uses that stored copy.
2. **Find and parse scripts.** The migration service looks up the bundled
   `migrations` directory, reads its `.sql` files, validates the numeric
   filename prefixes, rejects duplicate IDs, and sorts the scripts by numeric
   ID. A missing bundle, malformed filename, unreadable file, or duplicate ID
   stops the migration run.
3. **Open the configured database and ledger.** The service opens the existing
   SQLite database (it does not create a missing database) and ensures the
   `woa_migration` table exists. The ledger stores each migration's ID,
   filename, timestamp, result (`success` or `failure`), and error detail.
4. **Run pending migrations.** A migration whose ID already has a successful
   ledger entry is skipped. Each other script runs in its own
   `BEGIN IMMEDIATE` / `COMMIT` transaction, and its success is recorded in
   that transaction. Scripts must not start or commit transactions themselves.
5. **Record and surface failures.** If a script fails, its transaction is
   rolled back and a failure entry is recorded. The service logs and throws the
   error, stopping the batch; later migrations in the batch do not run. Only
   successful IDs are skipped on the next attempt, so the failed migration can
   be retried on the next launch or by using the retry button. If rollback or
   failure recording also fails, that additional detail is included in the
   surfaced error.
6. **Validate and connect.** After all pending migrations succeed, the
   application validates the expected WOA schema, marks the database connected,
   and loads table statistics. On import, this is a second validation, after
   migrations. A database is not made available to feature views when migration
   fails.

The database itself is application data, not a bundled resource. An imported
SQLite file is copied to
`Application Support/WOA/database/woa.db`; its connection settings are stored
separately in `Application Support/WOA/configuration/app-settings.json`.
`UserDefaults` are for small preferences, not the database or migration ledger.
Import uses the system file picker and temporarily accesses the selected file;
because WOA copies it into Application Support, it does not need a persistent
security-scoped bookmark to use the imported database on later launches.

## Views and failure behavior

- **`MainView` / `MainNavigationView`** own the migration service and typed
  navigation route. `MainView` opens migration history in the main navigation
  stack; it is not a separate window or sheet.
- **`DatabaseManagementView`** is the root gate for database setup and
  connection. It shows a loading state during connection. On a migration error
  it replaces the normal content with **“Database Migration Required”** and
  **“The database could not be updated. WOA cannot continue until the migration
  succeeds.”** It also displays the detailed error text and a **“Retry
  Migrations”** button. The ViewModel leaves the database disconnected and
  `isReadyForUse` false, which disables access to database-dependent features
  until retry succeeds.
- **`DatabaseSelectorView`** lets the user choose and import a database when
  none is configured. During import it shows **“Validating database...”** and
  displays ordinary import/validation errors inline. A migration failure is
  promoted to the same blocking error in `DatabaseManagementView`, rather than
  allowing the import success screen to appear.
- **`TableStatusView`** is shown after successful import to confirm the imported
  database and its tables, with a **“Continue”** action. It is not shown when
  migration fails.
- **`LaunchScreenView`** shows the connected database and the migrations
  applied in the current session, with a link to the full history. A failure to
  read history is shown inline as **“Unable to load migration history: …”**.
  This is a history-display problem, distinct from a migration failure that
  blocks the database.
- **`MigrationHistoryView`** lists ledger entries newest first with filename,
  timestamp, success/failure status, error detail, and a current-session
  marker. It offers **“Refresh”**, shows **“No Migrations Applied”** when the
  ledger has no entries, and shows **“Unable to Load Migration History”** plus
  the underlying error if history cannot be read.

For common migration failures, the detailed blocking error identifies the
problem: for example, a missing bundle asks to reinstall the application;
invalid or duplicate filenames identify the offending name or ID; and SQL
execution errors include the migration filename and SQLite error. The failed
entry and details can also be inspected in Migration History if the ledger
remains readable.

## History and storage

The ledger is created by the application before scripts run and is separate
from any existing table named `migration`; the `woa_` prefix avoids collisions.
Migration history is kept in the target SQLite database, not in application
preferences or the app bundle. The history view orders entries by timestamp
descending, then ID descending. The current-session marker is runtime state and
is set only for migrations that succeeded during this launch.
