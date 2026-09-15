# Plan: Consulto Detail — View/Edit/Delete + Related Records (trattamenti, valutazioni, esami)

**Prompt:** `05_woa-consulto-manage.prompt.md`

## Decisions (confirmed with user)
- Include a full `esami` section too (list + add + edit/detail/delete), matching trattamenti/valutazioni, even though "Required Views" text only named the other two.
- Replace the existing read-only `PatientAppointmentDetailView` / `ConsultationDetailViewModel` in place with the new full-featured `ConsultoPatientDetailView` (same navigation route, extended).
- `valutazione.strutturale` / `cranio_sacrale` / `ak_ortodontica` are free-text nvarchar columns with no lookup table → render as plain (multi-line) `TextField`s.
- The green-check/red-cross result banner (with "back to consulto detail" button) appears after both **add** and **edit** operations on trattamento/valutazione/esame. Delete keeps the existing confirmation-dialog pattern (no banner needed, returns immediately).

## Scope

### In scope
- Consulto (`consulto` table) detail view: read-only display + edit mode (prefilled, same semantics as add) + delete with confirmation.
- Related record sections nested in the consulto detail view: `trattamento`, `valutazione`, `esame` — each as a collapsible list with minimal summary rows.
- Per related record: view details, edit, delete (with confirmation), and "Add new" from the section header.
- Dedicated Add view and dedicated Edit/Delete-capable Detail view for each of the 3 related record types, pushed into the main navigation stack (no sheets/windows).
- Result banners (success/failure) after add/edit of related records, with a button back to the consulto detail.
- Data model, repository, and DataChangeCoordinator event wiring for all 3 related tables plus consulto update/delete.
- Wiring `PatientDetailView`'s consultation row tap to open the new `ConsultoPatientDetailView` instead of the old read-only view.

### Out of scope
- `anamnesi_prossima` table (not mentioned in this prompt).
- Changes to `paziente`/patient-level flows beyond the existing entry point.
- New DB schema/migrations (all needed tables already exist in `data/woa-schema.sql`).
- esame's `tipo` lookup UI beyond a simple Picker bound to `lkp_esame`.

## Schema reference (already exists, no migration needed)
- `consulto(ID, ID_paziente, data, problema_iniziale)`
- `trattamento(ID, ID_consulto, ID_paziente, data, descrizione)`
- `valutazione(ID, ID_consulto, ID_paziente, strutturale, cranio_sacrale, ak_ortodontica)` — no date/description; free-text fields only.
- `esame(ID, ID_consulto, ID_paziente, data, descrizione, tipo)` + `lkp_esame(ID, descrizione)` lookup for `tipo`.

## Architecture (reuse existing patterns)
```
ConsultoPatientDetailView (SwiftUI, replaces PatientAppointmentDetailView)
    ↓
ConsultoDetailViewModel (@MainActor, replaces ConsultationDetailViewModel; adds edit/delete/related lists)
    ↓
PatientRepository (extended: consulto update/delete, trattamento/valutazione/esame CRUD)
    ↓
SQLiteConnection
```
Related-record Add/Edit views follow the exact same shape as `AddConsultationView` / `ConsultationCreateViewModel` already in the codebase (form → validate → submit → publish `DataChangeEvent` → pop route). Edit views additionally load existing values and call an `update` repository method, then show the result banner instead of auto-popping.

Navigation stays within `SettingsView`'s single `NavigationStack` + typed `NavigationRoute` enum (per AGENTS.md guardrails) — no sheets/new windows for these features, consistent with current `.addConsultation`/`.consultationDetail` cases.

## Steps

### Phase 1 — Models (`src/WOA/Models/PatientDetail.swift`)
1. Extend `ConsultationDetail` to be editable and to carry what's needed for edit mode (already has `date`, `initialProblem` as `var` — reuse as the consulto edit form directly, no new "form" struct needed; mirrors `PatientCreateRequest`/`ConsultationCreateRequest` pattern already used for create).
2. Add new models, following the existing `*Summary` / `*Detail` / `*CreateRequest` triads:
   - `TreatmentSummary { id, date, description }`, `TreatmentDetail { id, consultoID, patientID, date, description }`, `TreatmentCreateRequest { consultoID, patientID, date, description }`.
   - `EvaluationSummary { id, structural, cranioSacral, akOrthodontic }` (no date in schema — list rows show a short excerpt of the 3 fields instead), `EvaluationDetail { id, consultoID, patientID, structural, cranioSacral, akOrthodontic }`, `EvaluationCreateRequest { consultoID, patientID, structural, cranioSacral, akOrthodontic }`.
   - `ExamSummary { id, date, typeName, description }`, `ExamDetail { id, consultoID, patientID, date, typeID, typeName, description }`, `ExamCreateRequest { consultoID, patientID, date, typeID, description }`, `ExamType { id, name }` (mirrors `AnamnesisType`, backed by `lkp_esame`).

### Phase 2 — Repository (`src/WOA/Repositories/PatientRepository.swift`)
*Depends on Phase 1 models.*
3. Add `updateConsultation(_:consultationID:databaseFileURL:) throws` and `deleteConsultation(id:databaseFileURL:) throws` (mirror `updatePatient`/`deletePatient`; delete only the `consulto` row — related-record deletion under a consulto is out of scope/documented as a note, matching the existing patient-delete comment "Related records are not automatically deleted").
4. Add fetch/create/update/delete for each of the 3 related tables, parallel to the consultation methods already present:
   - `fetchTreatments(for consultoID:) -> [TreatmentSummary]`, `fetchTreatment(by id:) -> TreatmentDetail?`, `createTreatment(_:) -> Int`, `updateTreatment(_:id:) throws`, `deleteTreatment(id:) throws`.
   - `fetchEvaluations(for consultoID:) -> [EvaluationSummary]`, `fetchEvaluation(by id:) -> EvaluationDetail?`, `createEvaluation(_:) -> Int`, `updateEvaluation(_:id:) throws`, `deleteEvaluation(id:) throws`.
   - `fetchExams(for consultoID:) -> [ExamSummary]`, `fetchExam(by id:) -> ExamDetail?`, `fetchExamTypes() -> [ExamType]` (from `lkp_esame`), `createExam(_:) -> Int`, `updateExam(_:id:) throws`, `deleteExam(id:) throws`.
   - Use the same parameterized-SQL / `SQLiteValue` / `stringValue`/`parseDate` helper conventions already in the file. All queries filtered by `ID_consulto = ?`, ordered `data DESC, ID DESC` where a date exists (evaluation has none — order by `ID DESC`).

### Phase 3 — DataChangeCoordinator events (`src/WOA/Services/DataChangeCoordinator.swift`)
*Parallel with Phase 2.*
5. Extend `DataChangeEvent` with `treatmentCreated/Updated/Deleted(treatmentID:consultoID:databaseURL:)`, `evaluationCreated/Updated/Deleted(evaluationID:consultoID:databaseURL:)`, `examCreated/Updated/Deleted(examID:consultoID:databaseURL:)`. Update the `databaseURL` computed property switch accordingly.
6. Use the existing (currently unused) `.consultationUpdated`/`.consultationDeleted` cases for the new consulto edit/delete flows.
7. Add `subscribeToConsultoChanges(consultoID:databaseURL:)` (mirrors `subscribeToPatientChanges`) returning an `AsyncStream` that reloads on any consultation-scoped or related-record event matching `consultoID`.

### Phase 4 — ViewModels (`src/WOA/ViewModels/PatientDetailViewModel.swift`)
*Depends on Phases 1–3.*
8. Replace `ConsultationDetailViewModel` with `ConsultoDetailViewModel`:
   - State: `consultation: ConsultationDetail?`, `treatments/evaluations/exams` arrays, `isEditing`, `editForm: ConsultationCreateRequest`-like fields (reuse simple `date`/`initialProblem` bindings), `isSaving`, `isDeleting`, `showDeleteConfirmation`, per-section `isXExpanded` bools, `errorMessage`.
   - `load()`, `beginEditing()`, `cancelEditing()`, `save()` (→ `updateConsultation`, publish `.consultationUpdated`), `delete()` (→ `deleteConsultation`, publish `.consultationDeleted`).
   - Subscribes via `subscribeToConsultoChanges` in `init`, same pattern as `PatientDetailViewModel.subscribeToChanges()`.
9. Add `TreatmentCreateViewModel`, `TreatmentEditViewModel`, `EvaluationCreateViewModel`, `EvaluationEditViewModel`, `ExamCreateViewModel`, `ExamEditViewModel` — Create variants mirror `ConsultationCreateViewModel`/`RemoteHistoryCreateViewModel`; Edit variants add `load()` to prefill from `fetch*(by id:)`, `save()` calling `update*`, and expose a `saveSucceeded: Bool?` (nil = not attempted, true/false drives the banner) instead of auto-completing via `onSuccess` closure.

### Phase 5 — Views (`src/WOA/Views/PatientDetailView.swift`, consider splitting into new file `ConsultoDetailView.swift` if the file grows too large — reuse existing single-file convention otherwise)
*Depends on Phase 4.*
10. Replace `PatientAppointmentDetailView` with `ConsultoPatientDetailView`:
    - Header: consulto date + problema iniziale prominently at top, with ✏️ edit icon button and 🗑️ delete icon button (per prompt's explicit emoji icons), matching `PatientDetailView.header` structure.
    - Read-only attributes vs. edit form toggle (same `DisclosureGroup`/form-swap pattern as `PatientDetailView.attributesSection`).
    - Delete confirmation via `.confirmationDialog`, mirroring existing patient delete flow.
    - Three `DisclosureGroup` sections — Treatments, Evaluations, Exams — each with an "Add" button in the header row and tappable summary rows (date + short text) that push to that record's detail/edit route; empty-state text when list is empty.
11. Add `AddTreatmentView`/`TreatmentDetailEditView`, `AddEvaluationView`/`EvaluationDetailEditView`, `AddExamView`/`ExamDetailEditView`:
    - Add views mirror `AddConsultationView`/`AddRemoteHistoryView` (form → submit → pop on success, inline error text on failure — consistent with existing add-flow UX) **plus** the newly required banner: after a successful/failed submit, show a persistent green-check / red-cross banner (do not auto-pop) with a "Back to consulto" button that pops the route; keep the form visible or replace it with the banner (recommend: show banner above the form, disable form, add explicit "Back" button — avoids surprising auto-navigation while satisfying "message... A button allows the user to navigate back").
    - Detail/Edit views combine read-only display + the same ✏️/🗑️ affordances as the consulto header, reusing the Edit view's form for in-place editing; same banner behavior for edit success/failure; delete uses `.confirmationDialog` and pops back to `ConsultoPatientDetailView` on confirm (no banner needed for delete, matching decision above).
    - Exam forms include a `Picker` bound to `fetchExamTypes()` (mirrors the existing anamnesis type Picker in `AddRemoteHistoryView`).

### Phase 6 — Navigation wiring (`src/WOA/Views/SettingsView.swift`)
*Depends on Phase 5.*
12. Extend the private `NavigationRoute` enum with: `.treatmentDetail(id:consultoID:databaseURL:)`, `.addTreatment(consultoID:patientID:databaseURL:)`, `.evaluationDetail(...)`, `.addEvaluation(...)`, `.examDetail(...)`, `.addExam(...)`. Keep `.consultationDetail` case name but point it at `ConsultoPatientDetailView` (rename the destination type only; route case name can stay to minimize churn, or rename to `.consultoDetail` for clarity — recommend renaming for readability since it's a private enum with a single call site to update).
13. Wire `ConsultoPatientDetailView`'s new callbacks (`onOpenTreatment`, `onAddTreatment`, `onOpenEvaluation`, `onAddEvaluation`, `onOpenExam`, `onAddExam`, `onDeleted`) to push/pop the new routes, following the exact closure-passing convention already used for `.patientDetails`/`.addConsultation`.
14. No changes needed to `PatientDetailView`'s `onOpenConsultation`/`onAddConsultation` wiring itself — it already routes through `.consultationDetail`/`.addConsultation`, which now resolves to the upgraded view/viewmodel.

## Relevant files
- `src/WOA/Models/PatientDetail.swift` — add Treatment/Evaluation/Exam model triads + ExamType.
- `src/WOA/Repositories/PatientRepository.swift` — add consulto update/delete + full CRUD for 3 related tables.
- `src/WOA/Services/DataChangeCoordinator.swift` — extend `DataChangeEvent` + add `subscribeToConsultoChanges`.
- `src/WOA/ViewModels/PatientDetailViewModel.swift` — replace `ConsultationDetailViewModel` with `ConsultoDetailViewModel`; add 6 new create/edit view models for related records.
- `src/WOA/Views/PatientDetailView.swift` — replace `PatientAppointmentDetailView`; add 6 new related-record views with banner UX.
- `src/WOA/Views/SettingsView.swift` — extend `NavigationRoute` + `navigationDestination` switch with 6 new cases and rewire the consultation case.
- `src/WOA.xcodeproj/project.pbxproj` — **only if new files are created** (e.g. if splitting into `ConsultoDetailView.swift`); must add PBXFileReference/PBXBuildFile/group/sources entries per repo convention. Preference: keep everything in the existing `PatientDetailView.swift`/`PatientDetailViewModel.swift`/`PatientDetail.swift` files to avoid pbxproj churn, matching how patient/consultation/history were all consolidated into these same files already.

## Verification
1. Build via existing Xcode scheme (`xcodebuild -scheme WOA -project src/WOA.xcodeproj build`) — must succeed with zero new warnings about unused `DataChangeEvent` cases.
2. Manual: open a patient → open a consulto row → confirm read-only attributes render, edit icon toggles form pre-filled with current values, save persists and refreshes, cancel discards changes.
3. Manual: delete icon shows confirmation dialog; confirming removes the consulto and returns to `PatientDetailView`, whose consultation list refreshes (via `DataChangeCoordinator`).
4. Manual: for each of trattamenti/valutazioni/esami — add a new record (form → banner → back button returns to consulto detail, list updated), open an existing record's detail, edit and save (banner shown, list reflects change), delete with confirmation (row removed, no stray banner).
5. Manual: confirm no separate window/sheet is ever used for any of the above — all detail/add/edit screens replace the main `NavigationStack` content area, with Home/Back toolbar still functional throughout.
6. Confirm `esame`'s type Picker lists all `lkp_esame` entries and persists the selected `tipo` correctly.

## Further considerations
1. Whether to keep the route enum case named `.consultationDetail` or rename to `.consultoDetail` — recommend renaming since it's private/single-call-site and improves clarity now that the view does much more than before.
2. Whether related-record deletion should cascade when a consulto is deleted — current patient-delete behavior explicitly does *not* cascade, so this plan keeps consulto delete non-cascading too for consistency; flag to user if cascading is actually desired later.
