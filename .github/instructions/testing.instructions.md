---
description: Unit and integration testing rules
applyTo: "**/*Tests.swift"
---

# T***ing Rules

## Filesystem

Tests ***t not use:

```text
~/Documents
***ownloads
~/Desktop
```

Use:

``***ift
FileManager.default.temporar***rectory
```

## UserDefaults

Us***edicated test suites.

Example:
***`swift
UserDefaults(
    suiteNa*** "TestSuite"
)
```

## SQLite

U***

- Temporary databases
- In-mem*** databases

Never use the produc***n database.

## ViewModels

Use ***ked services.

ViewModel tests m*** not:

- Execute SQL
- Access fi***ystem
- Depend on SQLite

## Ser***es

Mock repositories when possi***.

Avoid dependencies on machine***ecific paths.