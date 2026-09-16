---
name: "refactor-responsive-swiftui"
description: "Audit and refactor existing macOS SwiftUI views into responsive, window-adaptive layouts."
---

# Refactor SwiftUI UI for Responsive macOS Layout

Analyze the selected Swift files and all directly related parent views, child views, view models, layout helpers, and tests.

Apply the repository instructions in:

- `.github/instructions/swiftui-responsive-layout.instructions.md`

## Objective

Refactor the current macOS SwiftUI implementation so that:

- forms grow and shrink with the available width
- grids automatically adapt their column count or cell width
- groups of elements can change position or orientation when space changes
- compact windows remain usable
- large windows use the available space effectively
- layout changes do not reset user-entered values, selections, filters, or loading state

Preserve existing business behavior unless a change is necessary to correct an identified defect.

## Phase 1: Inspect the Existing Implementation

Before editing code:

1. Identify the root view and the actual resizable container.
2. Trace all directly related child views.
3. Identify state ownership and binding flows.
4. Find fixed `frame` dimensions.
5. Find `.position(...)` and layout-related `.offset(...)` usage.
6. Find nested stacks that assume a permanent orientation.
7. Find grids with a fixed number of columns.
8. Find `GeometryReader` usage and determine whether it is necessary.
9. Find direct `NSWindow` or resize-notification observation.
10. Identify clipping, overlapping, truncation, and minimum-size risks.
11. Identify duplicated business logic across alternative layouts.
12. Locate existing previews and layout-related tests.

Do not edit files until this inspection is complete.

## Phase 2: Produce a Concise Refactoring Plan

Provide a plan containing:

- affected files
- identified responsiveness problems
- proposed responsive strategy
- reusable layout components to extract
- state that must remain stable
- breakpoints, if necessary
- build and test commands to run

For every breakpoint, explain which content constraint requires it.

Do not introduce a breakpoint merely because it is a common screen width.

## Phase 3: Implement the Refactoring

Apply the plan directly.

Follow this preference order:

1. flexible frames, alignment, spacing, and layout priority
2. adaptive `Grid` or `LazyVGrid`
3. `ViewThatFits`
4. `NavigationSplitView`
5. `GeometryReader`
6. custom `Layout`
7. minimal AppKit interoperability

Specific requirements:

- replace absolute positioning used for primary layout
- replace unjustified fixed widths with minimum, ideal, or maximum constraints
- replace fixed grid column counts with adaptive columns where appropriate
- move repeated dimensions into named layout metrics
- extract compact and wide arrangements into focused views
- keep shared state above interchangeable layout variants
- add scrolling where content cannot shrink safely
- preserve keyboard and accessibility behavior
- preserve existing public APIs unless changing them is necessary
- avoid unrelated formatting or architectural changes
- do not duplicate business logic between responsive variants

## Phase 4: Add Validation

Add or update representative previews when practical:

- compact
- standard
- wide
- long-content or validation-error state, when relevant

If breakpoint selection is implemented as pure logic, add boundary tests for:

- immediately below the breakpoint
- exactly at the breakpoint
- immediately above the breakpoint

Use existing project test conventions.

Do not invent a new testing framework if the repository already has one.

## Phase 5: Build and Test

Discover the existing build and test commands from the repository.

Then:

1. compile the affected target
2. run relevant tests
3. resolve compilation failures introduced by the refactoring
4. resolve failing tests caused by the refactoring
5. do not suppress warnings or tests merely to obtain a successful result

If build or test execution is unavailable, state exactly what prevented validation.

## Phase 6: Report the Result

At completion, provide:

### Responsive strategy

Describe the selected layout approach.

### Files changed

List every modified or created file with a short reason.

### Behavior by available width

Describe the resulting behavior for:

- compact width
- standard width
- wide width

### Removed layout risks

List:

- fixed dimensions removed
- absolute positioning removed
- unnecessary geometry measurement removed
- duplicated layout logic removed

### Remaining fixed dimensions

List each remaining fixed width, height, offset, or breakpoint and justify it.

### Validation

Report:

- build command and result
- test command and result
- previews added or updated
- validation limitations

### Exceptions

Explicitly list any responsive-layout instruction that was not followed and explain why.

If there are no exceptions, state:

`No responsive-layout rule exceptions remain.`

## Guardrails

- Do not redesign the visual identity.
- Do not change business rules.
- Do not change persistence behavior.
- Do not replace working controls without a responsive-layout reason.
- Do not add third-party UI dependencies.
- Do not use AppKit unless SwiftUI cannot reasonably provide the required behavior.
- Do not claim success without reporting actual build and test results.

Suggested invocation

In Copilot Chat, select the relevant root SwiftUI view and invoke:

/refactor-responsive-swiftui


If you want to narrow its scope further:

/refactor-responsive-swiftui Refactor the selected root view and only its directly related child views. Preserve the existing visual design and application behavior.


Prompt files are intended for manually invoked, repeatable tasks, whereas instruction files provide persistent guidance for matching repository content. This separation matches both GitHub's documented repository customization model and the internal guidance surfaced in your Copilot materials.

Main improvements built into these files
Correct level of enforcement: the instruction file applies automatically to Swift code under src.
Content-driven responsiveness: breakpoints must be justified by content constraints, not copied from common web widths.
Controlled use of GeometryReader: it is available, but not treated as the default solution.
State safety: recomposition must not reset form values, selections, filters, or ongoing tasks.
Validation discipline: Copilot must build, test, and report actual results.
Exception visibility: any noncompliance must be explicitly disclosed rather than silently ignored.