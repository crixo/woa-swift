## Plan: Patient Detail Feature

Implement the patient detail workflow requested by `04_woa-patient-detail.prompt.md` inside the existing macOS SwiftUI single-window application. The feature will load a complete `paziente` record by ID, show editable patient attributes, list linked `consulto` and `anamnesi_remota` records, provide inline detail destinations and add forms for those linked records, and support confirmed patient deletion. The implementation must preserve the existing View -> ViewModel -> Repository -> SQLite layering and typed root navigation.

**Steps**

### Phase 1: Confirm data contracts and persistence boundaries

1. Use `data/woa-schema.sql` as the source of truth for all fields and relationships. Model every `paziente` column already represented by `PatientCreateRequest`; derive displayed age from `data_nascita` rather than adding an age field. Use `lkp_provincia` for province labels and `lkp_anamnesi` for anamnesis kind labels.
2. Add detail models for the complete patient, consultation summary/detail, and remote-history summary/detail. Keep IDs and database values available so edit/add operations can round-trip without relying on the reduced `PatientSearchResult`.
3. Add request models for creating/updating a consultation and anamnesis entry. Keep date parsing/formatting consistent with `PatientRepository` and handle null or malformed values defensively.
4. Extend `SQLiteConnection` with parameter binding for write statements, or an equivalent prepared-statement API, before implementing update/delete/insert operations. Do not introduce new interpolated SQL for user-controlled values.
5. Extend `PatientRepository` with methods to fetch one patient, fetch consultation/history summaries, fetch each linked record by ID, update/delete a patient, and create a consultation/history entry. Use explicit transactions where a write needs more than one statement, check affected-row counts, and log failures through `AppLogger`.

### Phase 2: Patient detail state and reusable form behavior

6. Create `PatientDetailViewModel` with the selected patient ID and database URL, loading/error state, patient data, consultation/history arrays, edit draft, validation errors, section expansion state, save/cancel state, and delete-confirmation state.
7. Reuse the validation and province-loading semantics from `AddPatientViewModel`: required `nome` and `cognome`, future-date validation for `data_nascita`, optional contact/address fields, and canonical province `sigla`. Prefer extracting a shared patient form model/view component only if its bindings remain simpler than duplicating the existing presentation.
8. Ensure cancel discards the draft and returns to read-only state; save updates the database and reloads the patient and linked lists; deletion only runs after explicit confirmation and returns to the previous route after success. Preserve an actionable error state for failed operations.
9. Create focused view models for consultation detail/add and anamnesis detail/add if needed by the existing architecture. They should own loading, validation, submit, and error state; views must not execute SQL or perform persistence decisions.

### Phase 3: Inline views and navigation

10. Replace the private placeholder patient detail destination in `src/WOA/Views/SettingsView.swift` with `PatientDetailView`. Keep the existing typed `NavigationRoute` and root `NavigationStack`; pass a patient ID and database URL or an equivalent hashable route payload rather than treating `PatientSearchResult` as a complete record.
11. Update `PatientsSearchView` and its view model callback so selecting a result opens the detail route using the patient ID. Preserve Home, Back, patient search, and database-selection actions in the persistent main navigation chrome.
12. Build `PatientDetailView` with three independently collapsible sections: patient attributes, consulti, and anamnesi remota. Show surname/name, ID, derived age, and profession prominently; show all other available attributes with clear labels and placeholders for missing values.
13. Add edit controls that switch the attributes section into the same pre-filled form semantics as Add Patient, with explicit save and cancel actions. Add a delete button with a confirmation prompt and disabled/loading state while deletion runs.
14. Add minimal consultation rows showing date and initial reason, with navigation to `PatientAppointmentDetailView` and an inline add-appointment destination. Add minimal history rows showing date and resolved kind, with navigation to `PatientHistoryDetailView` and an inline add-history destination.
15. Keep all feature destinations in the existing main content area. Do not add a feature sheet, popover, extra `WindowGroup`, or `NSWindowController`; “dismiss” means Back/path navigation. Define explicit `Hashable` route cases for patient, consultation, history, and add flows.

### Phase 4: Project registration and validation

16. Register each new Swift file in `src/WOA.xcodeproj/project.pbxproj` through the file reference, build file, architectural group, and Sources build-phase entries. Preserve unrelated project changes and validate the existing project’s identifier/parsing issue before relying on Xcode builds.
17. Add focused repository/view-model tests if a test target exists; otherwise validate through the existing build and a disposable schema/database fixture or a documented manual test matrix. Do not add schema migrations unless implementation discovers a genuine schema requirement.
18. Verify patient lookup, complete field rendering, missing values, derived age, prefilled edit/cancel/save behavior, validation failures, confirmed deletion, empty linked lists, consultation/history detail navigation, and successful add flows. Confirm the existing search, add-patient, database selection, and settings navigation still work.

**Relevant files**

- `.github/prompts/04_woa-patient-detail.prompt.md` — requested behavior and required views.
- `data/woa-schema.sql` — authoritative `paziente`, `consulto`, `anamnesi_remota`, and lookup-table columns.
- `src/WOA/Models/PatientCreateRequest.swift` — existing patient write fields and form contract.
- `src/WOA/Models/PatientSearchResult.swift` — reduced search result; use only as the navigation source, not the detail payload.
- `src/WOA/Repositories/PatientRepository.swift` — extend current patient/province queries and date mapping.
- `src/WOA/Utils/SQLiteConnection.swift` — add safe bound-parameter support for writes.
- `src/WOA/ViewModels/AddPatientViewModel.swift` and `src/WOA/Views/AddPatientView.swift` — reuse validation, province, date, and patient-form behavior.
- `src/WOA/ViewModels/PatientsSearchViewModel.swift` and `src/WOA/Views/PatientsSearchView.swift` — update the selection callback into the detail route.
- `src/WOA/Views/SettingsView.swift` — own the typed root path, persistent navigation chrome, and detail route replacement.
- `src/WOA/Models/PatientDetail.swift`, `ConsultationDetail.swift`, `RemoteHistoryDetail.swift` — new data contracts, names may follow repository conventions.
- `src/WOA/ViewModels/PatientDetailViewModel.swift` and linked-record view models — new state and action ownership.
- `src/WOA/Views/PatientDetailView.swift`, `PatientAppointmentDetailView.swift`, `PatientHistoryDetailView.swift`, plus add-form views — new inline destinations.
- `src/WOA.xcodeproj/project.pbxproj` — register every new Swift source file.

**Verification**

1. Run `xcodebuild -list` against `src/WOA.xcodeproj` after project registration; then run the repository’s macOS build/test command available in the environment.
2. Exercise repository operations against the schema fixture: fetch by ID, update all patient fields, delete exactly one patient after confirmation, list linked rows, fetch linked details, and insert consultation/history rows with bound parameters.
3. Exercise the UI from patient search: open a patient, inspect all three sections, collapse/expand each section, edit and cancel, save valid and invalid data, confirm and cancel deletion, open linked details, and add both linked record types.
4. Verify route payloads compile as `Hashable`, no feature view opens a separate window or sheet, and Home/Back remain available throughout nested navigation.
5. Verify regressions in database selection, province loading, add-patient creation, patient search, and empty/error states.

**Decisions**

- Implement consultation and anamnesis detail plus add flows in this feature, because the prompt explicitly requires both navigation to more detail and adding new records.
- Patient profile editing and deletion are in scope; consultation/history editing and deletion are excluded unless later requested.
- Age is derived from date of birth; no schema column or migration is needed.
- The patient detail feature is an inline destination in the existing single main window, despite the prompt’s “separate view” wording.
- Use parameterized SQLite statements for all new reads and writes. Avoid routine user selection of the application database and preserve existing Application Support storage.
- Preserve the current codebase and user changes; unrelated project-file identifier problems are a validation risk to report, not a reason to rewrite unrelated entries.

**Scope boundaries**

- Included: complete patient display/edit/delete, collapsible sections, consultation/history summaries, detail views, add flows, typed navigation, repository persistence, validation, logging, and project registration.
- Excluded: schema redesign, migrations without a discovered need, consultation/history edit/delete, bulk operations, audit history, import/export, and new windows or feature sheets.
