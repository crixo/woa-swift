---
description: Documentation st***ards
applyTo: "**/*.md"
---

# D***mentation Rules

## Storage Docu***tation

Always explain:

- UserD***ults = preferences
- Application***pport = application data
- SQLit*** Application Support
- Bookmarks***external user-selected resources***# Sandbox Documentation

Do not ***ommend:

```text
/Users/<user>
~***cuments
~/Downloads
```

for app***ation-owned data.

Preferred exp***ation:

- Application Support fo***nternal data
- NSOpenPanel for e***rnal files
- NSSavePanel for exp***s
- Security Scoped Bookmarks fo***ersistent external access

## Co***Samples

Prefer:

```swift
URL
`***
over string paths.

Avoid:

```***ft
try!
```

Avoid:

```swift
fa***Error()
```