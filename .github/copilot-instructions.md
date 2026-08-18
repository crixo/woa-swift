# macOS Application Architecture

## Technology Stack

- Swift
- SwiftUI
- SQLite
- App Sandbox Enabled

## Architecture

```text
View
ViewModel
Service
Repository
Storage
```

Rules:

- Views contain presentation logic only
- ViewModels manage UI state
- Services contain business logic
- Repositories contain persistence logic
- Storage services manage files and directories

## Planning Driven Development

The repository contains a `/plans` folder.

Plan files represent approved requirements, architecture decisions, and implementation roadmaps.

Before generating, modifying, or refactoring code:

- Review relevant plan files.
- Follow existing plans before introducing new patterns.
- Reuse architecture, services, repositories, and storage strategies already documented in plans.
- Preserve documented design decisions unless explicitly instructed otherwise.

When implementation changes a documented behavior:

- Update the corresponding plan.
- Keep plans and implementation aligned.

When no relevant plan exists:

- Prefer creating or extending a plan before introducing significant new architecture.

Plans should capture:

- Scope
- Requirements
- Architecture decisions
- Storage decisions
- Database decisions
- Implementation phases
- Acceptance criteria

Treat plans as the primary source of project-specific architectural guidance.

## Sandbox First

Assume App Sandbox is enabled.

Never use:

```text
~/Documents
~/Downloads
~/Desktop
/Users/<user>
```

Never hardcode filesystem paths.

## Application Data

Application-owned data must be stored in:

```swift
FileManager.default.urls(
    for: .applicationSupportDirectory,
    in: .userDomainMask
)
```

Preferred layout:

```text
Application Support/
└── AppName/
    ├── database/
    ├── configuration/
    ├── logs/
    └── cache/
```

## UserDefaults

Use UserDefaults only for:

- Theme
- Language
- Window size
- Window position
- Selected tab
- Small preferences

Never use UserDefaults for:

- Database
- Logs
- Files
- Cache
- Documents

## SQLite

Store SQLite in:

```text
Application Support/AppName/database/application.db
```

Do not require routine user selection of the application database.
Project-specific onboarding or import workflows may require an initial user-selected database that is subsequently copied into Application Support.

Never store SQLite in Documents or Downloads.

## Security Scoped Bookmarks

Use Security Scoped Bookmarks only for:

- User-selected files
- User-selected folders
- Imports
- Exports
- Git repositories

Never use bookmarks for internal application data.

## Error Handling

Do not generate:

```swift
try!
fatalError()
```

Prefer:

```swift
do {

} catch {

}
```

## Logging

Use:

```swift
import OSLog
```

Avoid:

```swift
print()
```

## Concurrency

Prefer:

```swift
async
await
Task
```

Avoid blocking the main thread.

## Path Handling

Use URL based APIs.

Preferred:

```swift
url.appendingPathComponent(...)
```

Never build paths using string concatenation.

## Github Copilot Instructions
- plan files must be stored in the `.github/plans/` folder at the root of the repository. The plan should be named as following: `<prompt_file_name>.plan.md` where `<prompt_file_name>` is the name of the prompt file that generated the code. For example, if the prompt file is named `01_woa-db-selector.prompt.md`, the plan file should be named `01_woa-db-selector.plan.md`.
