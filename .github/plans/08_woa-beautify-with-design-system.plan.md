Analyze the entire SwiftUI codebase and modernize the UI while preserving all business logic, navigation, APIs, models, and CRUD workflows.

Apply a consistent Apple-native design system across forms, lists, grids, search screens, detail views, and dashboards.

Create reusable SwiftUI extensions and components in a DesignSystem folder and replace duplicated styling with reusable modifiers such as .appCard(), .appPanel(), .appSection(), .appPrimaryButton() and .appSecondaryButton().

Use:
- Rounded card layouts (12-20pt radius)
- Material backgrounds when appropriate
- Consistent spacing system
- SF Symbols and semantic icons
- Proper typography hierarchy (headline, subheadline, body, caption)
- System adaptive colors and Dark Mode support
- ContentUnavailableView for empty states
- searchable() for search screens
- SwipeActions where relevant
- Improved row and card layouts instead of spreadsheet-like grids
- Better visual grouping of form sections
- ProgressView and skeleton-ready loading states
- NavigationStack and modern toolbar patterns

Reduce visual clutter, improve readability, increase information hierarchy, and ensure design consistency across all screens.

For each modified screen:
1. Identify UX/UI issues.
2. Explain improvements.
3. Refactor using reusable design-system components.
4. Avoid duplicated styling code.
