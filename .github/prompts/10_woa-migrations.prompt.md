---
name: woa-migrations
description: Create a migration process to support database evolution.
---

## Request
Create a migration process to support database evolution. The migration process should be able to create the necessary tables and columns in the database, as well as apply any necessary changes to existing tables and columns. The migration process should also be able to track which migrations have been applied to the database, and should provide a way to view the history of applied migrations.

## Features 
- The migrations should be executed automatically when the application is launched for the first time after the update that includes the feature requiring the migration(s).
- The applied migrations are diplayed into the main view, in the `MigrationHistoryView`, listing with a special focus all the migrations name applied to the current session. 
- If an error occurs during the migration process, the application should display an error message to the user and applications should not proceed with the launch until the migration is successfully completed. A detailed message is logged in the console and/or in a log file for debugging purposes. The error message should be clear and concise, indicating the nature of the error and any steps that can be taken to resolve it. Also in case of successful migration, a message should be logged in the console and/or in a log file indicating that the migration was successful. The message should include the name of the migration and the timestamp of when it was applied.
- The migrations are stored in a dedicated folder named `data\migrations`. During the build process, all the migration files are copied to the application bundle, and the application should be able to read and execute them from there. The migration files should be named in a way that indicates the order in which they should be executed, such as `000_schema.sql`, `001_migrations-process.sql`,`002_create-auditing-table.sql`, etc. The application verify agianst the database if the migration has already been applied, and if so, it should skip the migration and move on to the next one. The application should also log a message indicating that the migration was skipped because it had already been applied. 
If the `migration` table does not exist, the application should create it before executing any migrations. The `migration` table should be used to track which migrations have been applied to the database, and should include the following columns:
  - `id`: a unique identifier for the migration
  - `name`: the name of the migration as per file name\
  - `timestamp`: the timestamp of the migration's application
  - `result`: the result of the migration (success or failure)

## Required Views
- `MigrationHistoryView`: A sub-view in the main view that displays the history of applied migrations, including the migration name, timestamp, and result. The sub-view should sort the migrations by timestamp in descending order, with the most recent migration at the top. Special focus to the migration(s) applied during current session./

