# Plan: Anamnesi Remota (Remote Health History) Detail, Edit, and Delete

Source prompt: `.github/prompts/06_woa-anamnesi-remota-manage.prompt.md`

## Scope

Allow the user to view, edit, and delete an existing anamnesi remota (remote
health history) record from `PatientDetailView`. Currently
`PatientHistoryDetailView` is a read-only sub-view inlined inside
`PatientDetailView.swift`, backed by a load-only `RemoteHistoryDetailViewModel`
inlined inside `PatientDetailViewModel.swift`. No update/delete repository
methods exist yet for `anamnesi_remota`.

## Requirements

1. Reachable from `PatientDetailView` (already wired via `onOpenHistory`).
2. Displays all anamnesi remota attributes clearly, with labels.
3. Edit mode (toggled via `✏️`) mirrors the "Add Anamnesi Remota" form,
   pre-filled with existing values; user can save or cancel.
4. Delete via `🗑️` with a confirmation dialog before removal.
5. Per the 1:1 View/file rule, the view must live in its own dedicated file,
   separate from `PatientDetailView.swift`. Its ViewModel follows the same
   rule since it is no longer a trivial read-only sub-ViewModel.

## Architecture / Storage

No new storage or SQLite location changes. Reuses the existing
`anamnesi_remota` table and the existing `RemoteHistoryCreateRequest` /
`RemoteHistoryDetail` / `AnamnesisType` models. Reuses
`DataChangeCoordinator` event types `remoteHistoryUpdated` /
`remoteHistoryDeleted` (already defined) so `PatientDetailViewModel`'s
existing subscription auto-refreshes the parent list.

## Implementation Phases

### Phase 1 — Repository
Add to `PatientRepository.swift`:
- `updateRemoteHistory(_:id:databaseFileURL:)` — `UPDATE anamnesi_remota SET
  ID_paziente = ?, data = ?, tipo = ?, descrizione = ? WHERE ID = ?`, throwing
  `SQLiteConnectionError.queryFailed` if `changes != 1`.
- `deleteRemoteHistory(id:databaseFileURL:)` — `DELETE FROM anamnesi_remota
  WHERE ID = ?`.

### Phase 2 — ViewModel extraction and extension
Extract `RemoteHistoryDetailViewModel` out of `PatientDetailViewModel.swift`
into its own file `src/WOA/ViewModels/RemoteHistoryDetailViewModel.swift`.
Extend it (pattern mirrors `ExamEditViewModel`/`TreatmentEditViewModel`):
- `request: RemoteHistoryCreateRequest`, `types: [AnamnesisType]` (loaded in
  `init` via `fetchAnamnesisTypes`).
- `isSaving`, `isDeleting`, `showDeleteConfirmation`, `saveSucceeded`.
- `load()` populates `request` from the fetched `history`.
- `save()` calls `updateRemoteHistory` then publishes
  `.remoteHistoryUpdated(historyID:patientID:databaseURL:)`.
- `delete()` calls `deleteRemoteHistory` then publishes
  `.remoteHistoryDeleted(historyID:patientID:databaseURL:)`, returns `Bool`.

### Phase 3 — View extraction and extension
Extract `PatientHistoryDetailView` out of `PatientDetailView.swift` into its
own file `src/WOA/Views/PatientHistoryDetailView.swift`. Extend it (pattern
mirrors `ExamDetailEditView`):
- Read-only display: ID, date, type name, description, with `✏️` / `🗑️`
  actions.
- Edit mode: `Form` with `DatePicker`, `Picker` over `viewModel.types`,
  `TextField` (description, vertical axis), Cancel/Save actions.
- Save success/failure banner with a "Back to Patient" action, matching the
  Treatment/Evaluation/Exam edit views.
- Delete via `.confirmationDialog`, calling `onBackToPatient()` on success.

### Phase 4 — Wiring
- `SettingsView.swift`: update the `.historyDetail` route case to pass
  `dataChangeCoordinator` and an `onBackToPatient` callback (pop the
  navigation path) to the new `PatientHistoryDetailView`.
- Remove the old inlined `struct PatientHistoryDetailView` from
  `PatientDetailView.swift` and the old inlined
  `class RemoteHistoryDetailViewModel` from `PatientDetailViewModel.swift`.

### Phase 5 — Xcode project registration
Add `PBXFileReference` + `PBXBuildFile` + group children + Sources build
phase entries in `WOA.xcodeproj/project.pbxproj` for the two new files,
following the existing `PatientDetailView.swift` / `PatientDetailViewModel.swift`
entry pattern.

## Acceptance Criteria

- Opening a history entry from `PatientDetailView` shows all its attributes.
- Editing and saving updates the record and refreshes `PatientDetailView`'s
  history list via `DataChangeCoordinator`.
- Deleting (after confirmation) removes the record, refreshes the parent
  list, and navigates back to `PatientDetailView`.
- `PatientHistoryDetailView` and `RemoteHistoryDetailViewModel` each live in
  their own dedicated file.
- All new/modified Swift files are registered in `project.pbxproj`.
