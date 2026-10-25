# Database migrations

## Scope

Provide versioned SQL migrations for the app-owned SQLite database. Apply pending migrations after database import and on each configured-database startup before WOA exposes the connected experience. Show migration history in the existing main window.

## Architecture

- `DatabaseMigrationService` discovers and orders bundled SQL scripts, applies one script per transaction, tracks successful migration IDs applied during the current app session, and provides history data.
- `DatabaseMigrationRepository` creates and queries the `woa_migration` ledger using `SQLiteConnection`.
- The code creates the namespaced ledger table if it does not exist. It stores the numeric filename prefix as `id`, the full filename as `name`, an epoch-millisecond `timestamp`, a `success`/`failure` `result`, and optional failure detail. The `woa_` prefix avoids colliding with any existing `migration` table in imported databases.
- Scripts live in `data/migrations` and are copied as a folder resource into the app bundle. Prefixes must be unique and followed by `_` or `-`; already-applied scripts must not be renamed or edited.
- Each migration's SQL and success ledger update commit atomically. On failure, rollback that migration, persist a failure row, stop the batch, and block database use until retry succeeds. Previously committed migrations remain applied. Failure retries update the row for that migration.
- `MigrationHistoryView` is reachable from the migrations section in the connected database screen, sorted newest first, and marks successful migrations applied during the current session. The section sits directly below the database table section and reports when no migrations were applied.
- Views remain presentation-only. Migration work runs off the main actor and uses the existing SQLite and logging helpers.

## Storage and database decisions

- Continue using the imported app-owned database under Application Support.
- Create the `woa_migration` table before running scripts. The migration runner owns this table; feature scripts must not create or alter it.
- Migration scripts must not contain transaction-control statements because the runner manages transactions.
- This feature adds no schema-specific migration scripts; future schema changes add forward-only scripts in `data/migrations`.

## Acceptance criteria

- Scripts run in ascending numeric-prefix order and successful IDs are skipped on subsequent launches with a log entry.
- Failure results and diagnostic details are logged and surfaced; later scripts do not run until retry succeeds.
- Startup and import do not expose a connected database before migrations and validation complete.
- History shows name, timestamp, result, newest first, and highlights successes from the current app session.
- Xcode includes the new Swift sources and bundles the migrations folder.
