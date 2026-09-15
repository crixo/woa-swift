---
description: "macOS-only platform enforcement for all Swift source files"
applyTo: "src/**/*.swift"
---

Whenever working on Swift code, begin your answer with:
[SWIFT_RULE_ACTIVE]

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

Force the relation 1:1 between Views and swift files. The 1:1 exception applies only to true sub-views: views that render exclusively in service of one parent feature view and are not independently reachable destinations. Concretely:
- A sub-view (e.g. a read-only detail view opened only via a callback from its parent feature view) may live in the same file as that parent view, even if the actual navigation switch/router lives in a different file (e.g. a central settings or router view's `NavigationStack`).
- A view that represents its own data-entry or primary destination (e.g. an "Add *X*" form) must get its own dedicated file, regardless of which parent view triggers navigation to it.
- Any view that represents a data-entry or creation form (e.g. "Add *X*" / "Create *X*") is always its own destination, never a sub-view, even when it is only reachable from one parent feature view. It must live in its own dedicated file, not bundled inside the file of the view that triggers navigation to it.
- When such a form view is split into its own file, its backing ViewModel must move with it into its own dedicated ViewModel file, following the `<ViewName>ViewModel` naming convention used across the codebase.

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

The 1:1 relation between Views and Swift files also applies to ViewModels: each ViewModel should have its own dedicated file, except for true sub-ViewModels that exist solely to support a single parent ViewModel.

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

### State Synchronization (Data Change Events)

Mutations (create/update/delete) must not refresh other views through UUID
refresh tokens or success callbacks. Use the shared `DataChangeCoordinator`
instead:

- `DataChangeCoordinator` is a service-layer, app-scoped `@MainActor` object.
  It is in-memory UI synchronization state only — never persisted.
- Change events are typed: entity type, operation (`created` / `updated` /
  `deleted`), entity ID, optional parent ID, and database identity.
- Subscriptions use `AsyncStream`. Every subscriber must cancel its
  subscription when its owning ViewModel is deinitialized or replaced.
- Publish an event only after the corresponding repository call succeeds.
  Never publish after a validation failure or a database error.
- Repositories must stay persistence-only and must never reference the
  coordinator.
- Navigation callbacks remain for navigation only — never repurpose them to
  trigger data reloads.

Checklist for any new mutating feature:

1. Define (or reuse) an event type/operation for the entity.
2. Publish it only on success, including the database identity.
3. Subscribe in the affected ViewModel(s) and filter by relevance (entity ID
   / parent ID / database identity).
4. Cancel the subscription on teardown.