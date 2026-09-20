## Plan: modal CRUD result feedback for exam editing

TL;DR: Replace the inline success/error card in `ExamDetailEditView` with a modal popup pattern that appears after save, keeps the form visible on a failed save, and logs the detailed failure while showing a short user-facing message. The plan reuses the existing `ExamEditViewModel` state and the app’s current design tokens rather than adding a new architecture.

**Steps**
1. Confirm the exact result flow in `ExamDetailEditView`: the current `saveSucceeded` branch renders a reusable card and is the one targeted by this prompt. This is the only replacement point for the CRUD-result modal behavior.
2. Add a dedicated modal state to the view layer for the exam edit flow, such as a `@State private var resultState: CRUDResultState?` with `success` and `failure` values. This should be triggered after `viewModel.save()` completes and should replace the existing card-based branch rather than layering a second result UI.
3. Update the save logic in `ExamEditViewModel` to keep a concise user-facing message and a detailed debug string. The short message should be displayed in the modal; the long error text should be logged via `AppLogger.error(...)` while the UI remains minimal and readable.
4. Update the modal presentation so success shows a green state and a dismiss/back action, while failure shows a purple error state and remains on the current view with a single “Close” action. The modal should not use both colored text and colored background simultaneously, to match the requirement for a clean visual treatment.
5. Remove the old inline save-result card branch from `ExamDetailEditView` and replace it with the modal-driven flow. Keep the edit form behavior intact for both successful and failed saves so the user can continue or return to the previous view as needed.
6. Validate the resulting UI logic by checking the relevant Swift file for compile-time correctness and ensuring no `UIKit`-only patterns or navigation violations are introduced.

**Relevant files**
- `src/WOA/Views/PatientDetailView.swift` — `ExamDetailEditView` and the shared `saveResultCard` helper currently handle the CRUD result display; this is the primary edit site.
- `src/WOA/ViewModels/PatientDetailViewModel.swift` — `ExamEditViewModel.save()` owns the save result state and error capture; this is where the detailed error can be logged with minimal UI output.
- `src/WOA/Utils/AppLogger.swift` — existing logging facility used to write detailed error data to the OS log and app log file.

**Verification**
1. Review the updated `ExamDetailEditView` to confirm the modal appears only after save attempts and replaces the previous inline result card.
2. Check `ExamEditViewModel.save()` to confirm any failure path logs the full diagnostic message and only stores a short user-facing summary.
3. Inspect the modal branch for the required state styling: green for success, purple for failure, and a single action button in each case.
4. Run a focused compile check for the Swift app, if available in the local environment, to confirm the change builds without introducing navigation or view-state issues.

**Decisions**
- Scope is deliberately limited to `ExamDetailEditView`; other CRUD result views are excluded per the prompt restriction.
- The implementation will reuse the existing `saveSucceeded` and `errorMessage` patterns to avoid broad refactors and preserve consistency with the app’s architecture.
- The full database or validation error should remain in logs, with the modal showing only the concise guidance needed for user recovery.

**Further considerations**
1. If the design requires a more reusable modal pattern later, the same state model can be extracted into a shared helper without changing the current scope.
2. If the app already has a preferred modal style elsewhere, mirror that exact color and spacing pattern rather than introducing a new visual language.
