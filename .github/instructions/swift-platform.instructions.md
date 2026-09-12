---
description: "macOS-only platform enforcement for all Swift source files"
applyTo: "src/**/*.swift"
---

# Swift Platform Rules (macOS only)

This file loads automatically whenever Copilot reads or writes a `.swift`
file under `src/` — you do not need to reference it from a prompt.

- Never emit `import UIKit` or any `UI*` type (`UIColor`, `UIView`,
  `UIViewController`, `UIImage`, `UIFont`, `UIApplication`, `UIDevice`).
- Never use iOS-only SwiftUI modifiers: `.navigationBarTitle`,
  `.navigationBarItems`, `.statusBar(hidden:)`,
  `.navigationViewStyle(StackNavigationViewStyle())`.
- Never write a real implementation inside `#if os(iOS)` — macOS only.
- For form fields, pickers, and other UI inputs, use SwiftUI's cross-platform
  controls (`TextField`, `Picker`, `Toggle`, `DatePicker`) with no UIKit
  bridging. Only use `NSViewRepresentable` (AppKit), never
  `UIViewRepresentable`.
- File selection must use `NSOpenPanel` / `NSSavePanel`, never
  `UIDocumentPickerViewController` or any iOS document picker.

If a task appears to require an iOS-only capability, do not substitute the
iOS API silently — ask for the AppKit/macOS equivalent or flag the gap.

## SwiftUI Rules

### Views

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

### ViewModels

ViewModels:

- Hold UI state
- Call services
- Handle errors
- Coordinate async work

ViewModels must not:

- Execute SQL
- Access filesystem directly

### State

Preferred:

```swift
@State
@StateObject
@ObservedObject
@Environment
```

Avoid global mutable state.

### Main Actor

UI facing ViewModels should be:

```swift
@MainActor
```

### Dependency Injection

Prefer constructor injection.

Bad:

```swift
let service = CustomerService()
```

Good:

```swift
init(service: CustomerServiceProtocol)
```