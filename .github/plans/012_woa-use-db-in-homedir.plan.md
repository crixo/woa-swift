# Choose direct or copied database use

## Scope

Keep the existing mandatory database selection and status flow, and allow the
user to choose between using the selected `.db` file directly and copying it
into Application Support. Direct use is the default; copy mode remains
available when macOS sandbox permissions prevent SQLite from managing
sidecars beside an external file.

## Requirements

- The selector remains the mandatory first-run experience and remains
  reachable when reselecting a database.
- Add an unchecked-by-default copy checkbox on the selector. Its state is
  transient and is not saved separately.
- For direct use, persist the external path and security-scoped bookmark, and
  run SQLite operations against the selected database. The bookmark should
  reference the user-selected containing folder so SQLite can access sibling
  journal files.
- For copy mode, use the existing installer and save the Application Support
  database path.
- Preserve current database validation, migration, table-count display, and
  reselect behavior.
- Existing settings that point into Application Support remain valid.

## Architecture

- The view model retains/restores external security-scoped access for the
  active lifetime when direct use is selected. If an older direct-file
  bookmark exists, request the containing folder's scope and migrate settings
  to the directory bookmark.
- Use `DatabaseInstaller` only when copy mode is selected.
- Keep optional bookmark persistence backward-compatible with older settings.
- No new Swift files are needed; existing files are already members of the
  Xcode target.

## Acceptance criteria

- The copy checkbox is present and defaults to unchecked.
- Direct mode opens the selected database; a pre-existing `.db-wal` file is
  not required by the selection flow.
- Folder-level permission is requested via `NSOpenPanel` and persisted as a
  security-scoped bookmark; the app does not receive broad home-directory
  access.
- Copy mode opens the Application Support copy and retains the prior import
  behavior.
- Table names and counts are displayed for the database actually in use, and
  existing Application Support configurations still connect normally.

SQLite may check for or create a `-wal` sidecar in direct mode. If sandbox
permissions reject access to required sidecars, users can choose copy mode;
SQLite then manages those files in Application Support.
