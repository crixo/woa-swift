---
name: bug-finder-swift
description: Bug-hunting guidance for Swift, SwiftUI, and macOS code, Package.swift, Xcode project settings, entitlements, and privacy manifests. Use when reviewing these files for concrete defects (correctness, concurrency, security, lifecycle). Loaded by the Repository Bug Finder agent.
---

# Skill: Swift / SwiftUI / macOS

> Adds to the core agent. Cannot relax any core rule.

## Activates on

`**/*.swift`, `**/Package.swift`, `**/*.xcodeproj/**`, `**/*.xcconfig`, `**/*.xcscheme`, `**/*.xctestplan`, `**/*.entitlements`, `**/PrivacyInfo.xcprivacy`

## Context to gather first

- `Package.swift` and project settings: Swift language mode, strict-concurrency setting, deployment targets, targets and their dependencies.
- App entry point (`@main`, `App`, `AppDelegate`) and scene structure.
- Persistence layer (SwiftData, Core Data, files, UserDefaults, Keychain) and networking layer.
- Entitlements and sandbox status.

## Defect patterns

### Correctness

- force unwraps (`!`), `as!`, `try!`, `fatalError`/`precondition` on values that can be nil or invalid at runtime;
- array/collection indexing without bounds guarantees; `first!`/`last!`; ranges with reversed bounds (runtime trap);
- integer overflow or traps from arithmetic or conversions (`Int` to `Int32`, `UInt` subtraction, `Int(someDouble)` with NaN/infinity);
- incorrect optional handling (`if let` shadowing that discards the value, `??` defaults that mask failures);
- stale or duplicated state; incorrect `Equatable`/`Hashable`/`Identifiable` implementations (equality inconsistent with hash, identity that changes);
- incorrect `Codable` (missing keys, wrong key strategy, date strategy mismatch, enums without unknown-case handling, `decodeIfPresent` hiding errors);
- locale/calendar/time-zone errors (`DateFormatter` without fixed locale for fixed formats, `Calendar.current` for UTC logic, week-year `YYYY` instead of `yyyy`, DST arithmetic with `addingTimeInterval`);
- API availability assumptions not guarded by `#available` or deployment target;
- multi-window or multi-scene state assumptions (singletons assuming one window);
- persistence: partial writes (non-atomic `Data.write`), missing `save()`, saving off the owning context/actor, migrations that lose data;
- sandbox-path assumptions (hard-coded home paths, `~` not expanded, writing outside the container);
- file-system check-then-use races (`fileExists` followed by read/write).

### SwiftUI

- wrong property-wrapper ownership: `@ObservedObject` for an object created in the view body (recreated on re-render), `@StateObject` initialized from changing inputs, `@State` holding a reference type that should be observed, `@Binding` copies;
- duplicated sources of truth between `@State`, model, and environment;
- `ForEach` with unstable identity (`id: \.self` on non-unique or mutable values, `UUID()` generated in the body, index-based ids over mutable arrays);
- `@EnvironmentObject`/`@Environment` read without a guaranteed injection (runtime crash);
- inconsistent navigation state (path and selection disagree, stale destination after deletion);
- UI mutation off the main actor;
- `.task`/`Task {}` started in a view and capturing state after the view is gone, or missing `.task(id:)` so it does not restart when its input changes.

Report only when a concrete incorrect behavior results.

### Concurrency

- actor-isolation violations and `nonisolated`/`@MainActor` mismatches;
- shared mutable state without synchronization; `@unchecked Sendable` types that actually mutate unsynchronized state;
- `Task.detached` or unstructured `Task {}` with no owner, no cancellation, or that escapes the intended lifetime;
- cancellation not propagated (`Task.isCancelled`/`checkCancellation` never consulted in long loops; `try?` swallowing `CancellationError`);
- `CheckedContinuation`/`UnsafeContinuation` resumed zero times (hang), twice (crash), or on a path that can throw before resuming;
- actor reentrancy: state checked before an `await` and assumed unchanged after it;
- GCD/async bridging bugs: completion handlers called multiple times or never, `DispatchQueue.main.sync` from the main thread (deadlock), `sync` on a queue the caller already owns;
- task-ordering assumptions (assuming two unstructured Tasks execute in creation order).

Do not mechanically flag weak/strong captures or concurrency annotations. Establish a plausible failure path.

### Security and privacy

- secrets or tokens in source, plists, `.xcconfig`, or `UserDefaults` (use of Keychain expected);
- entitlements broader than the code requires (`com.apple.security.app-sandbox` disabled, `files.all`, `network.server` without a server, `cs.disable-library-validation`, `cs.allow-unsigned-executable-memory`, `cs.allow-jit`);
- `App Transport Security` exceptions (`NSAllowsArbitraryLoads`) without need;
- `URLSession` delegates that accept any server trust (`.useCredential` on every challenge);
- `Process`/`NSTask` with user-influenced arguments or a shell (`/bin/sh -c`) with string interpolation;
- path traversal when joining user- or network-supplied components onto a base URL; `URL(fileURLWithPath:)` on untrusted relative paths;
- `NSKeyedUnarchiver` without secure coding, deserialization of untrusted plists;
- `print`/`NSLog`/`Logger` of tokens, PII, or full request bodies without `.private`;
- `startAccessingSecurityScopedResource()` not balanced by `stop…` on all paths, or bookmark data not refreshed when stale;
- privacy-manifest (`PrivacyInfo.xcprivacy`) inconsistencies: required-reason APIs used but not declared, tracking domains mismatching network use. Report only with a concrete risk.

### Resource and lifecycle

- retain cycles through closures stored on `self` (timers, Combine sinks, `NotificationCenter` block observers, `Task` stored on self capturing self strongly for its lifetime);
- observers/timers/`AnyCancellable`s not retained (silently stop) or not removed;
- unbounded caches or arrays;
- file handles, streams, and `FileHandle`s not closed;
- cancellation leaving state half-updated (flag set before an await that can be cancelled, never reset).

### Error handling

- empty `catch`, `try?` where the failure matters (data loss, silent no-op on save), `try!`;
- retries of non-idempotent operations;
- `Result`/optional conversions that turn distinct errors into `nil` and change UI behavior;
- cancellation treated as a user-visible error, or as success.

## Safe validation

Only if already installed and consistent with core safety rules:

- `swift package describe`
- `swift build`
- `swift test` (optionally `--enable-code-coverage`)
- `xcodebuild -list`, `xcodebuild -showBuildSettings`
- `xcodebuild build`, `xcodebuild test` (use the repository's documented scheme/destination; do not enable signing or notarization)
- `swiftlint lint`, `swiftformat --lint .`
- `plutil -lint <file>` for plists/entitlements

Never run: `xcodebuild archive`/`-exportArchive`, `notarytool`, `codesign` with a real identity, `xcrun altool`, `swift package update`/`resolve` that rewrites `Package.resolved`, `pod install`.

If a build writes into the repository (derived data, `.build`), direct it to a temporary location when the tool allows (`-derivedDataPath`, `--scratch-path`) and never leave tracked files modified.

## Severity notes

- Critical/High: data loss or corruption, crash on a common launch/save path, security-relevant entitlement or trust-validation defect, deadlock on the main thread, build or test configuration that ships a wrong artifact.
- Medium: crash or wrong output on a less common path, leak that grows with normal use.
- Low: cosmetic or rare-edge incorrect behavior.

## Known false positives

- `!` on values proven non-nil by construction in the same scope (e.g. a literal `URL(string: "https://…")!` with a constant valid string; `IBOutlet`s). Report only if the constant is actually invalid.
- `@unchecked Sendable` where all mutable state is demonstrably guarded by a lock or confined to one queue.
- `Task {}` inside `.task` or `@MainActor` methods that are awaited or cancelled by the owner.
- `[weak self]` omitted for short-lived closures that do not outlive the owner.
- `try?` where the result is demonstrably irrelevant (best-effort cleanup, cache read with fallback).
