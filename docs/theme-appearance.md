# Application theme and appearance

This document explains how the System, Light, and Dark theme options work for
users and how the implementation is connected across WOA.

## User experience

Open **Settings** and choose a value in the **Tema** picker:

- **Sistema** follows the current macOS appearance.
- **Chiaro** applies the macOS Aqua appearance.
- **Scuro** applies the macOS Dark Aqua appearance.

The selection is previewed immediately across the app, including the main
window and its controls. Choose **Salva** to persist the selected theme. Choose
**Annulla**, or leave Settings without saving, to restore the previously saved
appearance. The theme is loaded when the application starts, so a saved
selection remains in effect on the next launch.

## Implementation

Theme is represented by `AppSettings.Theme` (`system`, `light`, and `dark`) in
[`AppSettings.swift`](../src/WOA/Models/AppSettings.swift). It is part of the
existing application settings model and uses the existing JSON settings
persistence; no separate theme storage or database field was added.

The implementation involves these code paths:

1. [`SettingsView.swift`](../src/WOA/Views/SettingsView.swift) binds the picker
   to `SettingsViewModel.draft.theme`. When it changes, the view asks the
   ViewModel to preview the new value.
2. [`SettingsViewModel.swift`](../src/WOA/ViewModels/SettingsViewModel.swift)
   coordinates previewing, saving, and discarding the settings draft. The
   ViewModel is retained by `MainView` while Settings is open so store updates
   during preview do not recreate the draft. It is refreshed from persisted
   settings when Settings is opened again.
3. [`AppSettingsStore.swift`](../src/WOA/Services/AppSettingsStore.swift)
   keeps an optional, in-memory theme preview separate from the persisted
   `settings`. `appearanceTheme` resolves to the preview when present and to
   the saved theme otherwise. Saving updates the persisted settings and clears
   the preview; discarding the preview restores the saved value.
4. [`WOA.swift`](../src/WOA/WOA.swift) observes the effective theme and sets
   `NSApp.appearance` to the corresponding AppKit appearance. A `nil`
   appearance for System allows macOS to determine the appearance.
5. [`MainView.swift`](../src/WOA/Views/MainView.swift) explicitly discards the
   preview before navigating away from Settings on Cancel. The Settings view
   also discards a remaining preview when it disappears, covering other ways
   of leaving the destination.

Settings are encoded and saved by `ConfigurationService` in the app's
Application Support configuration area. Application Support is for
application-owned data; `UserDefaults` is for small preferences and is not
used to store this settings file. SQLite application data is also kept in
Application Support, while security-scoped bookmarks are for persistent access
to external user-selected resources.

## Behavior and boundaries

- Preview state is in memory only. It does not write to the settings file.
- Save uses the existing settings save flow, so the theme is persisted together
  with other valid settings.
- Cancel discards the preview and does not change the stored theme.
- System removes the app-level appearance override, returning appearance
  control to macOS.
- The setting changes appearance only; it does not change data, navigation, or
  window layout.
