# Plan: Display Settings in Launch Screen

**Prompt:** `07_woa-display-settings-in-launch-screen.prompt.md`

## Objective

Display the persisted application settings alongside the selected database table status in the connected launch screen. Show the full settings-file path, move database reselection below the table list, and require confirmation before resetting the database configuration.

## Scope

### Included

- New `LaunchScreenView` composing the connected launch surface.
- New `ApplicationSettingsView` displaying the settings-file path and all current settings attributes.
- Responsive two-panel layout with a table panel on the left and settings panel on the right.
- Confirmed database reselection from the table/status panel.
- Exposure of the canonical settings-file URL through `SettingsViewModel`.
- Xcode project registration for both new Swift files.
- Documentation alignment if the existing settings-flow documentation describes the old toolbar behavior.

### Excluded

- Editing application settings.
- Changes to JSON persistence or database installation.
- Database schema, repository, or migration changes.
- New navigation destinations or additional windows.
- New test targets or unrelated responsive refactors.

## Architecture

The existing architecture remains unchanged:

```text
SettingsView
    -> LaunchScreenView
        -> Table status/list panel
        -> ApplicationSettingsView
    -> SettingsViewModel
        -> ConfigurationService
            -> AppPaths
```

`SettingsView` remains the single navigation and root-state owner. `LaunchScreenView` is a presentation composition, not a new navigation root. Views do not perform file access or persistence.

## Implementation Phases

### Phase 1: Settings display

1. Add `src/WOA/Views/ApplicationSettingsView.swift`.
   - Accept `AppSettings` and a displayable settings-file path.
   - Show the full configuration path prominently.
   - Show labeled values for `databaseConnection`, `logLevel`, and `theme`.
   - Keep the view presentation-only.

2. Add `src/WOA/Views/LaunchScreenView.swift`.
   - Accept the table data, current settings, settings-file path, reselection callback, and any required table-panel callbacks.
   - Arrange the table panel on the left and settings panel on the right.
   - Use flexible sizing, a visible divider, and a compact stacked fallback for narrow windows.
   - Use scrolling where content cannot safely shrink.

3. Update `src/WOA/ViewModels/SettingsViewModel.swift`.
   - Resolve the settings path through `AppPaths.configurationFileURL()`.
   - Expose a user-readable fallback if resolution fails.
   - Log path-resolution failures without using force unwraps or fatal errors.
   - Leave `ConfigurationService` and `AppPaths` persistence semantics unchanged.

### Phase 2: Root wiring and reselection

4. Update `src/WOA/Views/SettingsView.swift`.
   - Render `LaunchScreenView` for the connected launch state.
   - Remove the toolbar-level `Re-select Database` button.
   - Preserve the existing typed `NavigationStack`, Home/Back actions, Patients Search action, loading state, selector state, and import-success transition.
   - Keep the existing post-import acknowledgement screen unchanged until Continue is pressed.

5. Update `src/WOA/Views/TableStatusView.swift`.
   - Add `Re-select Database` below the table summary.
   - Add local confirmation state using a transient confirmation dialog.
   - Invoke the injected reset callback only after confirmation.
   - Preserve the existing Continue behavior.

6. The two-panel launch composition appears after the post-import Continue action. The existing one-time import-success screen remains unchanged.

### Phase 3: Project and documentation consistency

7. Register both new Swift files in `src/WOA.xcodeproj/project.pbxproj`:
   - `PBXFileReference` entries.
   - `PBXBuildFile` entries.
   - Views group membership.
   - Sources build phase entries.

8. Update `docs/codebase/SettingsView.md` if needed to document that `LaunchScreenView` owns the connected launch composition and reselection is confirmed from the table panel. Preserve the documented sandbox and storage rules:
   - Application-owned settings remain in Application Support.
   - Paths are represented with `URL` APIs.
   - External database selection continues to use `NSOpenPanel`.

## Relevant Files

- `.github/prompts/07_woa-display-settings-in-launch-screen.prompt.md`
- `src/WOA/Views/SettingsView.swift`
- `src/WOA/Views/TableStatusView.swift`
- `src/WOA/Views/LaunchScreenView.swift`
- `src/WOA/Views/ApplicationSettingsView.swift`
- `src/WOA/ViewModels/SettingsViewModel.swift`
- `src/WOA/Models/AppSettings.swift`
- `src/WOA/Services/ConfigurationService.swift`
- `src/WOA/Utils/AppPaths.swift`
- `src/WOA.xcodeproj/project.pbxproj`
- `docs/codebase/SettingsView.md`

## Decisions

- Keep `SettingsView` as the only navigation owner.
- Use the existing JSON settings model and Application Support configuration path.
- Pass settings and the resolved path into `ApplicationSettingsView`; do not access files from the view.
- Put reselection confirmation at the launch/table surface and invoke the existing `resetConfiguration()` only after explicit confirmation.
- Preserve the database import and post-import Continue behavior.
- Use flexible SwiftUI layouts and `ViewThatFits` or an equivalent stacked fallback instead of fixed coordinates.

## Verification

1. Run `xcodebuild -list -project src/WOA.xcodeproj` on macOS or CI.
2. Run the Codemagic-equivalent build:

   ```text
   xcodebuild build -project src/WOA.xcodeproj -scheme WOA -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO
   ```

3. Verify the connected launch screen displays separated table and settings panels.
4. Verify the full canonical `app-settings.json` path and all settings labels are visible.
5. Resize the window at compact, medium, and wide sizes; confirm no clipping or overlap.
6. Cancel reselection and confirm state is unchanged.
7. Confirm reselection and verify the configuration resets and the database selector returns.
8. Verify database import and Continue behavior remain unchanged.
9. Confirm no additional window, sheet, popover, or navigation root was introduced.

The current repository has no `*Tests.swift` files or test target, so focused validation is build and manual behavior verification on macOS/CI.
