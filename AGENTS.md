# AGENTS.md — WOA Agent Contract

This file is read automatically at the start of every Copilot Chat / Copilot
coding agent session — no `/command` required. It is an **always-on**
constraint layer, same tier as `.github/copilot-instructions.md`. Unlike
`.github/prompts/*.prompt.md`, nothing here depends on a feature prompt
being invoked, so these rules apply to every generation, edit, and refactor,
not just the ones that reference the architecture prompt.

## Platform constraint (hard rule, never overridable by a feature prompt)

WOA targets **macOS desktop only**. Never introduce iOS-only frameworks,
types, or modifiers — including inside "UI field" or form-input code, which
is where this has leaked before.

Forbidden, regardless of context:

- `import UIKit`
- `UIColor`, `UIFont`, `UIImage`, `UIView`, `UIViewController`
- `UIApplication`, `UIScreen`, `UIDevice`
- SwiftUI modifiers that are iOS-only: `.navigationBarTitle`, `.navigationBarItems`,
  `.statusBar(hidden:)`, `.navigationViewStyle(StackNavigationViewStyle())`
- `UIKit`-backed `UIViewRepresentable` wrappers
- Any `#if os(iOS)` branch that contains real (non-stub) implementation code

Required instead:

- `import AppKit` when an AppKit bridge is genuinely needed
- `NSColor`, `NSFont`, `NSImage`, `NSView`, `NSViewController` for AppKit interop
- macOS-native SwiftUI navigation (`NavigationSplitView`, `.toolbar`, `.navigationTitle`)
- `NSOpenPanel` / `NSSavePanel` for file selection (already required by the
  database onboarding flow)

**If a requested UI behavior seems to need an iOS-only API, stop and ask for
the AppKit/macOS-SwiftUI equivalent instead of silently adding the iOS
import.** Do not "fix it later" — do not emit the iOS code at all.

## Layered architecture (always enforced)

View → ViewModel → Service → Repository → Storage. Views never contain
persistence, validation, or migration logic — see
`.github/copilot-instructions.md` for the full rule set (sandboxing, SQLite
location, error handling, logging, concurrency, path handling). That file
is the canonical source for those rules; this file does not duplicate them
to avoid drift between two "always-on" documents.

## Plans and prompts

- `.github/prompts/00_woa-architecture.prompt.md` defines project scope and
  the data model reference. It is loaded only when a feature prompt
  references it — treat it as context, not as the source of hard
  constraints.
- `/plans` (or `.github/plans/`) holds approved architecture decisions.
  Check for a relevant plan before introducing new patterns.

## Self-check before finalizing any Swift file

Before returning generated or edited Swift code under `src/`, scan every
`import` statement and every type/modifier used against the forbidden list
above. If any match is found, remove it and substitute the macOS-native
equivalent before responding.
