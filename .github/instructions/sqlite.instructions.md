---
description: SQLite architecture and persistence
applyTo: "**/*Database*.swift,**/*SQLite*.swift,**/*Repository*.swift,**/*Migration*.swift"
---

# SQLite Rules

## Database Location

The application database lives at:

```text
Application Support/AppName/database/application.db
```

Project-specific onboarding workflows may initialize the internal database from a user-selected external database.
After initialization, application code should operate on the internal database located in Application Support.

Never store the database:

- In Documents
- In Downloads
- On Desktop
- Beside the application

## Database URL

Database URLs must come from a dedicated provider.

Preferred:

```swift
protocol DatabaseURLProviding {
    func databaseURL() throws -> URL
}
```

## Layering

Preferred architecture:

```text
SQLiteConnectionProvider
DatabaseMigrator
Repository
Service
ViewModel
View
```

## Repository Rules

Repositories may:

- Execute SQL
- Map records
- Open statements

Repositories must not:

- Access SwiftUI
- Show alerts
- Access Views

## Views

Views must never:

- Execute SQL
- Open SQLite
- Perform migrations

## ViewModels

ViewModels must never:

- Call sqlite3_open
- Execute SQL

## SQL

Always use prepared statements.

Bad:

```swift
let sql = "SELECT * FROM Customer WHERE Name='\(name)'"
```

Good:

```swift
let sql = "SELECT * FROM Customer WHERE Name=?"
```

## Migrations

Use a dedicated migration component.

Preferred:

```swift
DatabaseMigrator
```

All schema changes must be versioned.

## Concurrency

Database work must not run on MainActor.

Prefer:

```swift
actor DatabaseActor {
}
```

or async repositories.