---
description: Documentation standards
applyTo: "**/*.md"
---

# Documentation Rules

## Storage Documentation

Always explain:

- UserDefaults = preferences
- Application Support = application data
- SQLite in Application Support
- Bookmarks for external user-selected resources

## Sandbox Documentation

Do not recommend:

```text
/Users/<user>
~/Documents
~/Downloads
```

for application-owned data.

Preferred explanation:

- Application Support for internal data
- NSOpenPanel for external files
- NSSavePanel for exports
- Security Scoped Bookmarks for persistent external access

## Code Samples

Prefer:

```swift
URL
```

over string paths.

Avoid:

```swift
try!
```

Avoid:

```swift
fatalError()
```