# Plan: Edit Application Settings

## Objective

Add a dedicated inline settings destination with separate editable and
read-only sections. Persist user preferences through the existing
`AppSettingsStore` and `ConfigurationService`, and use
`lastModifiedPatientsLimit` in recent-patient queries.

## Scope

- Add a Settings button to the persistent main toolbar.
- Place the Settings entry inside the main "Impostazioni applicazione" launch card.
- Add a typed `.settings` navigation route and dedicated `SettingsView`.
- Add `SettingsViewModel` for draft state and save validation.
- Split editable and system settings visually.
- Validate `lastModifiedPatientsLimit` as a positive integer.
- Preserve settings JSON compatibility with a default effective limit of 5.
- Use the configured limit in `PazienteSearchView` and
  `PazienteSearchViewModel`.
- Register both new Swift files in the Xcode target.
- Update relevant architecture and project-settings documentation.

## Architecture

```text
MainNavigationView
  -> .settings route
  -> SettingsView
      -> SettingsViewModel
          -> AppSettingsStore
              -> ConfigurationService
                  -> Application Support JSON
```

Views remain presentation-only. Persistence remains in `AppSettingsStore` and
`ConfigurationService`. The Settings destination does not create a window,
sheet, or popover.

## Editable settings

- Theme
- Log level
- Google authentication enabled
- Google authentication client type
- Last modified patients limit

The limit must parse as a positive `Int`. Blank, negative, zero, and
non-integer input is rejected with inline feedback.

Theme selection previews the corresponding app appearance immediately. The
preview is committed on Save and discarded when the Settings destination closes
without saving.

## System settings

- Settings-file path
- Database path
- Database connection status
- Last validation time
- Application version

These values are read-only and clearly separated from editable controls.

## Backward compatibility

`lastModifiedPatientsLimit` is optional in `AppSettings` so settings JSON saved
before this field existed continues to decode. `effectiveLastModifiedPatientsLimit`
returns the persisted positive value or 5 for missing/invalid values.

## Acceptance criteria

- A Settings button opens the inline settings destination.
- Home and Back navigation remain available.
- Save persists valid settings and Cancel discards draft changes.
- Changing Theme immediately previews System, Light, or Dark appearance;
  leaving Settings without saving restores the persisted theme.
- Save and Cancel appear in a dedicated bottom action box, with Cancel on the left and Save on the right.
- Invalid limits are not persisted.
- Older settings files resolve to the default limit of 5.
- Recent-patient loading uses the effective configured limit.
- The Settings and ViewModel Swift files are in the Xcode Sources build phase.
- The macOS build succeeds without iOS-only APIs or separate navigation roots.
