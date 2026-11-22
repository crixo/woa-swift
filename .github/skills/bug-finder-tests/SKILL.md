---
name: bug-finder-tests
description: Bug-hunting guidance for test code, fixtures, mocks, and test plans in any language. Use when reviewing tests for concrete defects such as tests that cannot fail, flaky or order-dependent tests, and tests silently skipped or not run. Loaded by the Repository Bug Finder agent.
---

# Skill: Tests and test infrastructure (language-neutral)

> Adds to the core agent. Cannot relax any core rule. Use together with the language skill of the test code (for example `bug-finder-swift`).

## Activates on

`**/Tests/**`, `**/*Tests/**`, `**/test/**`, `**/tests/**`, `**/__tests__/**`, `**/*Test.*`, `**/*Tests.*`, `**/*.test.*`, `**/*.spec.*`, `**/fixtures/**`, `**/*.xctestplan`

## Context to gather first

- How tests are run in CI and in the documented developer workflow (command, scheme, test plan, target, filter flags).
- Which targets/projects/test plans exist and which are wired into the run.
- Shared test helpers, base classes, fixtures, mocks, and setup/teardown.
- Known flaky or skipped tests and why (comments, issues referenced in code).

## Defect patterns

### Tests that cannot fail or assert the wrong thing

- missing assertions; assertions on values that are always true (comparing a value to itself, asserting a mock returned what the test just stubbed);
- assertions inside callbacks/closures/async blocks that never execute before the test ends, so nothing is verified;
- expectations/promises created but never awaited or never fulfilled, or awaited with a timeout whose failure is not asserted;
- `try?` / swallowed errors in test bodies that hide the failure the test should catch;
- assertions of the buggy behavior (expected values copied from current output) when the specification or surrounding code shows different intended behavior;
- wrong operand order or wrong tolerance (floating-point comparisons with a tolerance large enough to pass anything);
- tests with a name that promises one scenario but exercise another, where this leaves a real defect unprotected.

### Unreliable tests

- fixed sleeps or real timers/clocks instead of controllable time or explicit waits;
- non-determinism: unseeded randomness, current date/time, locale, time zone, hash/iteration order, parallel execution order, available CPU/network;
- order dependence and shared mutable state: singletons, statics, global caches, `UserDefaults`, environment variables, current directory, keychain, shared temp paths, shared databases;
- setup/teardown that leaks state when a test fails or throws, or that cleans the wrong thing;
- tests that mutate the developer's real data or settings;
- tests touching real network, real services, production credentials, or user home directories;
- race conditions between the test and background work it started.

### Mocks, fakes, and fixtures

- mocks/fakes that diverge from real behavior (error semantics, ordering, threading, nullability) so tests pass while production fails;
- over-mocking that replaces the code under test;
- stale, invalid, or unrealistic fixtures that no longer match the real format consumed by the code;
- fixtures containing real secrets, personal data, or customer data (redact in the report);
- large generated fixtures committed but out of sync with their generator.

### Tests silently not running

- skipped/disabled/filtered tests (`skip`, `xit`, `@Test(.disabled)`, `XCTSkip`, `-skip-testing`, test-plan exclusions, `only`) covering code that ships, without a documented reason;
- test files or targets that exist but are not included in any target, test plan, or CI invocation;
- CI/test commands that run a subset (wrong filter, wrong path) or against a different configuration than the shipped one (Debug vs Release behavior differences that matter);
- test discovery rules that miss naming patterns used in the repository (for example a method not prefixed as the framework requires);
- tests whose result is not propagated (exit code lost in a wrapper script).

### Coverage

Do not report missing tests or low coverage as bugs by themselves. A coverage gap is reportable only when it leaves a specific, already identified defect unprotected, and then it belongs in "Suggested regression tests" rather than as its own bug.

## Safe validation

Only if already installed, and only commands documented by the repository or its CI, after reading the test runner configuration and confirming the tests do not touch real services or user data:

- the repository's documented test command (for example `swift test`, `xcodebuild test`, `pytest`, `npm test`) restricted to a narrow target or filter where possible;
- list-only modes that enumerate tests without running them (for example `swift test list`, `xcodebuild -enumerate-tests`, `pytest --collect-only`) to detect tests that are not discovered.

Never run tests that require production credentials or network resources you cannot confirm are local, and never run test suites that write outside a temporary location.

## Severity notes

- High: a test that can never fail guarding a critical path, or skipped/disabled tests that hide a real failure in shipped code, or tests that destroy real user data.
- Medium: flaky tests that intermittently block or mislead CI; mocks that hide a real divergence.
- Low: poor naming or redundant tests with no hidden defect.

## Known false positives

- Intentionally tautological tests used as compile-time checks (documented).
- Skipped tests with a documented, still-valid reason and an issue reference, covering code that is not shipped or is platform-gated.
- Tolerances that are justified by documented numerical behavior.
- Singleton usage in tests that reset the singleton in setup and teardown.
