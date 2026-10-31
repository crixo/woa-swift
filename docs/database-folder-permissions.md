# Direct database access and sandbox permissions

## Why folder permission is needed

WOA runs with the macOS App Sandbox enabled. The existing
`com.apple.security.files.user-selected.read-write` entitlement lets the user
choose a file, but SQLite may need to create or open sibling files while
using a database. In WAL mode these are typically `<database>-wal` and
`<database>-shm`. A grant scoped only to the `.db` file may not authorize
access to those neighboring files.

The database itself remains a single selected `.db` file. A pre-existing
`.db-wal` file is not required: SQLite creates and removes journal sidecars as
needed. WOA does not require the user to select sidecars individually.

## What WOA does

When **Copy selected database into Application Support** is unchecked:

1. The user selects the `.db` file.
2. WOA asks the user to select the folder containing that database. The
   selected folder must be the database's immediate parent folder.
3. WOA creates and stores a security-scoped bookmark for that folder and keeps
   the folder's security scope active while SQLite uses the database.
4. On subsequent launches, WOA resolves the bookmark and restores access to
   the folder before migrations, validation, or queries run.

The bookmark is saved permission for the one user-approved folder. WOA does
not receive unrestricted access to the user's home directory. If access is
revoked, the folder is moved, or the bookmark cannot be resolved, WOA reports
an error and the user can grant the database folder again or choose copy mode.
The macOS security-scoped bookmarks don’t normally expire after a set time. WOA saves the bookmark and resolves it on later launches. If macOS marks it stale, WOA attempts to refresh it. When WOA resolves the bookmark, it checks whether macOS marked it stale. If so, WOA creates and saves a refreshed bookmark automatically; there’s no separate prompt for that. It happens in `src/WOA/ViewModels/DatabaseManagementViewModel.swift/resolveDatabaseUsingDirectoryBookmark(_:)`. It checks isStale at line 197 and, when needed, recreates and saves the bookmark at line 200.

When copy mode is checked, WOA copies the selected database into Application
Support and runs SQLite against that app-owned copy. Sidecar files are then
managed in Application Support and no external folder permission is needed
for database operations.

## Storage locations

The database copy, app configuration, and other app-owned data live in
Application Support. Small preferences belong in `UserDefaults`; database
files and other app-owned documents do not. In direct mode, the original
database is an external user-selected resource and its folder permission is
represented by the security-scoped bookmark.

## Tradeoff

Direct mode operates on the original database, so migrations and user changes
are written to that file and its SQLite-managed sidecars. Use copy mode if the
database folder is read-only, on storage that does not support SQLite's
journaling requirements, or if macOS does not grant the required folder
access.
