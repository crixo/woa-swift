---
description: SwiftUI and MVVM
applyTo: "**/*.swift"
---

# SwiftUI Rules

## Views

Views are presentation only.

Views may:

- Render UI
- Trigger actions
- Bind state

Views must not:

- Execute SQL
- Read files
- Create repositories
- Create services
- Open databases

Bad:

```swift
Button("Load") {
    sqlite3_open(...)
}
```

## ViewModels

ViewModels:

- Hold UI state
- Call services
- Handle errors
- Coordinate async work

ViewModels must not:

- Execute SQL
- Access filesystem directly

## State

Preferred:

```swift
@State
@StateObject
@ObservedObject
@Environment
```

Avoid global mutable state.

## Main Actor

UI facing ViewModels should be:

```swift
@MainActor
```

## Dependency Injection

Prefer constructor injection.

Bad:

```swift
let service = CustomerService()
```

Good:

```swift
init(service: CustomerServiceProtocol)
```