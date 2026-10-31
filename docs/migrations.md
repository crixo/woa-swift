# Database migrations and audit history

WOA applies bundled SQL migrations to the active SQLite database before
database-backed features become available. This happens for a newly selected
database and on later launches when new migrations have shipped.

## Where migrations live and how they ship

Migration scripts live in [`data/migrations`](../data/migrations/). The Xcode
project includes this directory as a folder resource in the WOA target, so the
SQL files are copied into the app bundle's `Contents/Resources/migrations`
directory. At runtime,
[`DatabaseMigrationService`](../src/WOA/Services/DatabaseMigrationService.swift)
loads scripts from that bundled resource; it does not read them from a working
tree or a user-selected folder.

Build and release instructions are in
[Build, release, and installation](build-and-release.md).

## Add a migration

1. Add a forward-only `.sql` file under `data/migrations/`.
2. Start the filename with a unique numeric migration ID followed by `_` or
   `-`, for example `002_add_example_index.sql`.
3. Keep the migration ID unique by numeric value: `1_...sql` and
   `001-...sql` are duplicates.
4. Do not edit, rename, or reuse an ID after it has been applied. Add a new
   migration for subsequent schema changes.
5. Do not create or alter `woa_migration` in a script; the app owns that
   ledger. Do not add transaction statements: the service wraps each script in
   its own transaction.

Scripts are ordered numerically by their prefix, not lexicographically. A
missing bundled directory, malformed filename, duplicate numeric ID, or
unreadable SQL file stops the migration run.

## Runtime process

1. **Resolve the active database.** On later launches, WOA restores the saved
   database path and, for direct external access, resolves its security-scoped
   folder bookmark. During selection, WOA either uses the selected database
   directly or installs a copy in Application Support.
2. **Load and validate scripts.** The service reads `.sql` files from the
   bundled `migrations` resource, validates their IDs, and sorts them.
3. **Open the database and ledger.** WOA opens the existing database (it does
   not create a missing database) and creates `woa_migration` if necessary.
   Each ledger row contains the migration ID, filename, timestamp, result
   (`success` or `failure`), and optional error detail.
4. **Skip completed work.** Only IDs with a successful ledger entry are
   skipped. Failed entries remain eligible for retry.
5. **Apply one script transactionally.** The service starts
   `BEGIN IMMEDIATE`, executes the script, records success, and commits. If SQL
   fails, it rolls back and records the failure. A failed migration stops the
   batch; later scripts do not run.
6. **Connect only after success.** WOA validates the expected core tables,
   marks the connection ready, and loads table statistics. A database with a
   migration failure stays disconnected until the user retries or selects a
   recovery action.

If rollback or failure recording also fails, that additional failure detail is
included in the surfaced error. Retrying the next launch or choosing **Retry
Migrations** reruns failed IDs while leaving successful IDs skipped.

## User-visible behavior and history

Migration errors block database-backed features. The database management
screen shows **Database Migration Required**, the underlying error, and
recovery actions where applicable:

- Retry migrations.
- Grant access to the database's containing folder and retry.
- Copy an external database into Application Support and retry.
- Choose another database.

The **Migration History** destination reads `woa_migration` newest first and
shows each filename, timestamp, success/failure status, error detail, and
whether it succeeded during the current app session. A history-display error
is reported separately from a migration failure that blocks startup.

The migration ledger is stored in the active SQLite database, not in
`UserDefaults` or the app bundle. It is distinct from any pre-existing table
named `migration`.

## Audit history

[`001_create-auditing-table.sql`](../data/migrations/001_create-auditing-table.sql)
creates `woa_auditing` and indexes its timestamp and `(entity_table, entity_id)`
columns. Each row records:

- `entity_table` and `entity_id`
- `recorded_at` in UTC
- `change_type`: `create`, `added`, `update`, or `delete`

The repository's mutation helper performs the entity write and its audit insert
in the same SQLite transaction. If either fails, the transaction is rolled
back. The last-modified-patients query maps supported patient, consultation,
remote-history, treatment, evaluation, and exam changes to their patient and
shows the most recently changed patients. Its default display limit is five.

This audit table stores change metadata only. It does not preserve old/new
field values or provide a general-purpose revision history. The `woa_migration`
ledger tracks schema changes; `woa_auditing` tracks application entity
mutations.
