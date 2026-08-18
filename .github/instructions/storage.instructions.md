---
description: Sandbox storage and preferences
applyTo: "**/*Storage*.swift,**/*Settings*.swift,**/*Preferences*.swift,**/*Path*.swift"
---

# Storage Rules

## Application Support

Application-owned files must live under:

```swift
FileManager.default.urls(
    for: .applicationSupportDirectory,
    in: .userDomainMask
)
```

Directory structure:

```text
Application Support/
└── AppName/
    ├── database/
    ├── configuration/
    ├── logs/
    └── cache/
```

## UserDefaults

Allowed:

- Theme
- Last selected tab
- Window size
- Language
- Feature flags

Forbidden:

- SQLite
- Logs
- Files
- Documents
- Large JSON

## Preferences Pattern

Preferred:

```swift
protocol PreferencesStoring {
    var theme: String { get set }
}

final class PreferencesStore: PreferencesStoring {
}
```

## Security Scoped Bookmarks

Use Security Scoped Bookmarks only for user-selected external resources.

Examples:

- Import sources
- Export destinations
- User-selected files
- User-selected folders
- External databases
- Git repositories

Application-owned data must not depend on external bookmarks after import unless explicitly required by the project.

## File Access

Use:

```swift
NSOpenPanel
```

for user-selected files.

Use:

```swift
NSSavePanel
```

for user-selected output locations.

## Paths

Always use:

```swift
URL
```

Never build filesystem paths with string concatenation.