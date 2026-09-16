---
applyTo: "src/**/*.swift"
description: "Enforces responsive SwiftUI layouts for macOS applications."
---

# Responsive SwiftUI Layout Rules

## Scope

Apply these rules to all new and modified macOS SwiftUI views.

## General Rules

- Build layouts based on the available container size.
- Support continuous window resizing.
- Allow forms, grids, panels, and content blocks to grow and shrink.
- Reorganize content when the available space becomes insufficient.
- Preserve view state during layout changes.
- Keep essential content accessible at the minimum supported window size.
- Do not assume fixed window sizes, screen sizes, or monitor resolutions.

## Framework

- Use SwiftUI by default.
- Prefer standard SwiftUI containers and layout APIs.
- Use AppKit only when SwiftUI cannot provide the required behavior.
- Isolate AppKit integrations in focused wrappers.
- Document the reason for every AppKit dependency.

## Layout Strategy Priority

Use the first suitable strategy:

1. Flexible frames, alignment, spacing, and layout priority
2. Adaptive `Grid` or `LazyVGrid`
3. `ViewThatFits`
4. `NavigationSplitView`
5. `GeometryReader`
6. Custom `Layout`
7. AppKit interoperability

## Flexible Sizing

- Use `maxWidth: .infinity` where content should expand horizontally.
- Use `maxHeight: .infinity` where content should expand vertically.
- Define minimum dimensions only where required for usability.
- Prefer flexible constraints over fixed dimensions.
- Allow labels and values to wrap.
- Do not reduce font sizes only to fit content.
- Use scrolling when content cannot shrink safely.
- Use `layoutPriority` intentionally.
- Avoid broad or unnecessary use of `fixedSize`.

Example:

    .frame(
        minWidth: LayoutMetrics.minimumContentWidth,
        maxWidth: .infinity,
        alignment: .leading
    )

## Responsive Grids

- Prefer adaptive grids in resizable containers.
- Define a meaningful minimum cell width.
- Allow grid cells to expand with the available space.
- Avoid fixed column counts unless explicitly required.
- Prevent clipping and overlapping.
- Preserve readable content and usable controls.

Example:

    LazyVGrid(
        columns: [
            GridItem(
                .adaptive(minimum: LayoutMetrics.minimumCardWidth),
                spacing: LayoutMetrics.gridSpacing
            )
        ],
        spacing: LayoutMetrics.gridSpacing
    ) {
        // Content
    }

## Dynamic Composition

Reorganize layouts when proportional resizing is insufficient:

- Change horizontal content blocks to vertical blocks.
- Change multi-column forms to single-column forms.
- Move secondary content below primary content.
- Collapse secondary panels where appropriate.
- Replace detailed blocks with compact alternatives.
- Adjust grid columns automatically.

Prefer `ViewThatFits` when SwiftUI can select the first layout that fits.

Example:

    ViewThatFits(in: .horizontal) {
        WideContentLayout()
        CompactContentLayout()
    }

Use `GeometryReader` only when explicit measurement or content-driven breakpoints are required.

Example:

    GeometryReader { geometry in
        Group {
            if geometry.size.width >= LayoutMetrics.wideBreakpoint {
                WideContentLayout()
            } else {
                CompactContentLayout()
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

- Do not use `GeometryReader` when flexible frames, adaptive grids, standard containers, or `ViewThatFits` are sufficient.
- Do not nest `GeometryReader` instances unless every measurement is necessary.

## Breakpoints

- Use breakpoints only for structural layout changes.
- Base breakpoints on minimum usable content dimensions.
- Consider control widths, readable content widths, spacing, clipping, and overlap.
- Use the minimum number of breakpoints.
- Centralize breakpoints and reusable dimensions.
- Use semantic names.
- Do not scatter unexplained numeric values across views.

Example:

    private enum LayoutMetrics {
        static let compactBreakpoint: CGFloat = 640
        static let wideBreakpoint: CGFloat = 1_000
        static let minimumContentWidth: CGFloat = 320
        static let minimumCardWidth: CGFloat = 260
        static let gridSpacing: CGFloat = 16
        static let contentSpacing: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
    }

## Layout Structure

- Keep the view `body` concise.
- Extract compact, standard, and wide layouts into focused views or computed properties.
- Reuse the same state and business logic across layout variants.
- Do not duplicate data loading, persistence, validation, filtering, sorting, commands, business rules, or asynchronous operations.

Example:

    private var wideLayout: some View {
        HStack(
            alignment: .top,
            spacing: LayoutMetrics.sectionSpacing
        ) {
            FormPanel()
            DetailPanel()
        }
    }

    private var compactLayout: some View {
        VStack(
            alignment: .leading,
            spacing: LayoutMetrics.sectionSpacing
        ) {
            FormPanel()
            DetailPanel()
        }
    }

## State Preservation

Window resizing and layout recomposition must not reset:

- Form values
- Validation state
- Selections
- Sorting
- Filters
- Expanded or collapsed state
- Loading state
- Application state

Additional requirements:

- Keep shared state above interchangeable layout variants.
- Pass bindings, values, actions, or models to layout variants.
- Do not create independent state for each layout variant.
- Use stable identities for views and collection elements.
- Do not trigger data reloads, persistence operations, or asynchronous tasks during resizing unless explicitly required.

## Positioning

Do not use these techniques for primary layout:

- `.position`
- Arbitrary `.offset`
- Hard-coded coordinates
- Screen-based positioning
- Fixed window dimensions

Use stacks, grids, alignment, spacing, flexible frames, layout priorities, and custom layouts.

Use offsets only for decorative adjustments that do not affect logical layout, accessibility, keyboard navigation, hit testing, or resizing.

## Window Observation

- Do not observe `NSWindow` resize notifications for normal responsive layout.
- Use dimensions provided by the SwiftUI layout hierarchy.
- Observe window or screen notifications only when behavior depends on window position, display movement, display configuration, or the actual `NSWindow` frame.
- Isolate observation logic.
- Cancel observers correctly.
- Avoid retain cycles.
- Avoid redundant state updates.
- Perform UI state updates on the main actor.
- Document why SwiftUI layout information is insufficient.

## Minimum Size and Scrolling

- Define a usable minimum size for root layouts.
- Use scrolling instead of clipping or overlapping.
- Prefer vertical scrolling for forms.
- Use horizontal scrolling only when preserving the content structure requires it.
- Keep primary and destructive actions accessible.
- Do not hide essential functions at smaller sizes.

Example:

    ScrollView {
        ResponsiveContent()
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
    }

## Accessibility

Preserve:

- Keyboard navigation
- Logical focus order
- Accessibility labels
- Accessibility descriptions
- Readable text
- Usable control sizes
- Validation messages
- Error feedback
- Access to essential actions

Do not visually reorder controls when it produces an illogical focus order.

Do not truncate critical information unless the complete value remains accessible.

## Refactoring Rules

Before modifying an existing layout, inspect the relevant parent and child views.

Remove or justify:

- Fixed frame dimensions
- Absolute positioning
- Layout-related offsets
- Fixed grid column counts
- Permanent stack orientations
- Unnecessary `GeometryReader` usage
- Direct resize-notification handling
- Clipping and overlap risks
- Duplicated layout state
- Duplicated business logic

Preserve:

- Visual identity
- Business behavior
- Persistence behavior
- Public APIs unless a change is required
- Accessibility behavior

Avoid unrelated formatting, naming, or architectural changes.

## Completion Criteria

A responsive implementation must:

- Adapt to the available container size.
- Grow and shrink forms and grids appropriately.
- Recompose content when required.
- Remain usable at the minimum supported size.
- Preserve state during resizing.
- Avoid absolute positioning for primary layout.
- Centralize reusable layout values.
- Use content-driven breakpoints.
- Avoid duplicated business logic.
- Compile successfully.

## Required Copilot Output

For each implementation or refactoring:

1. State the selected responsive strategy.
2. Identify the layout mechanisms used.
3. Justify each breakpoint.
4. List and justify remaining fixed dimensions.
5. Report the compilation result.
6. Report any rule not followed and its justification.

Do not claim responsiveness without inspecting the relevant parent and child views.

Do not claim successful compilation unless the build command was executed successfully.