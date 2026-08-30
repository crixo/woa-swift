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

### Plan Files
- Plan files must be stored in the `.github/plans/` folder at the root of the repository
- The plan should be named as following: `<prompt_file_name>.plan.md` where `<prompt_file_name>` is the name of the prompt file that generated the code
- Example: if the prompt file is named `01_woa-db-selector.prompt.md`, the plan file should be named `01_woa-db-selector.plan.md`

### Xcode Project Management
**Critical:** After creating or modifying any Swift source files, **always update the Xcode project file** (`src/WOA.xcodeproj/project.pbxproj`) to include all changes. Failure to do so creates "ghost files" that compile in the IDE but are missing from the project configuration.

For each new file created:
1. **Add PBXFileReference entry** in the `/* Begin PBXFileReference section */` with:
   - Unique identifier (8 hex chars + 16 hex chars)
   - `lastKnownFileType = sourcecode.swift`
   - Correct file path relative to the group
2. **Add PBXBuildFile entry** in the `/* Begin PBXBuildFile section */` with:
   - Unique identifier
   - Reference to the PBXFileReference
3. **Add to group children** in the appropriate PBXGroup (Models, Views, ViewModels, etc.)
4. **Add to Sources build phase** in the `/* Begin PBXSourcesBuildPhase section */`

**Never skip this step.** Missing entries cause:
- Files not being compiled in Xcode builds
- Inconsistent state between filesystem and project configuration
- Build failures in CI/CD pipelines
- Xcode not recognizing file changes

**Verification:** After updating project.pbxproj, run `xcodebuild -list` or open in Xcode to confirm all files are recognized.
