---
name: woa-db-selector
description: Use it to scaffold the database selector allowing the user to identify the DB to be copied within the application container space.
---

<!-- Tip: Use /create-prompt in chat to generate content with agent assistance -->
## Request
Allow the user to select a SQLite database file from his home directory to have the WOA application copy it into the `Application Container` space as described by project architecture guidelines.

The selected database must be treated as an external source file only. The application must never validate, query, or migrate the source database in-place. The workflow must be:
1. copy the selected database into the sandboxed Application Support location
2. normalize the copied database if needed (for example WAL cleanup / journal reset)
3. validate the copied database schema
4. open the copied database for queries and table statistics

## Features
- Database Selection: 
If the database connection setting has not been configured, the starting page should provide a UI component to select the database file, copy it and store into a Sandbox-friendly location and configure the connection settings. If the database connection setting has been configured, the starting page should provide a UI component to test the connection to the database and display the connection status.
The connections status includes the list of all table with the number of records present in each of them in the manner of:
```
- paziente (100)
- consulto (332)
...
```
- Display settings: A starting page that provides a list of all configuration settings including the database connection settings, logging settings, and any other relevant application settings.
- Database import hygiene: before validating tables, the app must run any required imported-database normalization on the copied sandboxed file (for example remove stale `*.db-wal` / `*.db-shm` files and reset journal mode to `DELETE` when a source database was left in WAL mode by another tool).

## Required Views
- A that allow to list all configuration settings and should be available for the entire application lifecycle as entry page

- A view to show the list and record count of each table. This view is a one-time show as result of the succesful database selection process.


