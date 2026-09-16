# Plan: Responsive SwiftUI pass across WOA views

## Scope

Full-app pass, but limited to each root view + its own direct
children/subviews (no new shared/app-wide layout component file). Layout
metrics are centralized as a private `LayoutMetrics` enum per file, not a
shared module.

## Phases

### Phase A — DatabaseSelectorView / SettingsView / TableStatusView

Files:

- `src/WOA/Views/DatabaseSelectorView.swift`
- `src/WOA/Views/SettingsView.swift`
- `src/WOA/Views/TableStatusView.swift`

Findings: mostly already responsive (vertical VStacks, no fixed widths
beyond SettingsView's `.frame(minWidth: 420, minHeight: 320)` at line 256,
which is a justified usability minimum). Only risk: table-stat rows
(SettingsView ~L252, TableStatusView ~L22-26) have no wrap protection.

Changes:

1. SettingsView / TableStatusView: give each table-stat `Text` row
   `.frame(maxWidth: .infinity, alignment: .leading)` so it wraps instead of
   silently depending on parent width; no other structural change.
2. No other changes — DatabaseSelectorView's
   `.lineLimit(1).truncationMode(.middle)` path display is an intentional,
   justified truncation (full path shown via accessibility/tooltip is out
   of scope unless requested).

### Phase B — PatientsSearchView / AddPatientView

Files:

- `src/WOA/Views/PatientsSearchView.swift`
- `src/WOA/Views/AddPatientView.swift`

Problems found (PatientsSearchView):

- L35 `TextField(...).frame(width: 320)` — hard fixed width.
- L83-85 `ScrollView { ... }.frame(maxHeight: 280)` then
  `.frame(minWidth: 520, minHeight: 420)` on the root VStack — results area
  height is capped regardless of window size, and the root never grows to
  fill a larger window (no `maxWidth/maxHeight: .infinity`).
- L20-26 header `HStack` (title + Add Patient button) — low risk today but
  will be handled with the same `ViewThatFits` pattern used elsewhere for
  consistency once the view becomes narrower than 520pt.
- Result rows (L67-80): single vertical layout per result; acceptable but
  can offer a wide inline variant for better use of space.

Changes:

1. Replace the search `TextField` fixed width with
   `.frame(minWidth: LayoutMetrics.searchFieldMinWidth, maxWidth: LayoutMetrics.searchFieldMaxWidth, alignment: .leading)`.
2. Root container: add
   `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)`
   in addition to the existing `minWidth/minHeight` (keep the minimums —
   they're the justified usable-size floor).
3. Replace `ScrollView { ... }.frame(maxHeight: 280)` with
   `.frame(maxHeight: .infinity)` so results consume remaining vertical
   space.
4. Extract result row rendering into `resultRow(_ patient:)` using
   `ViewThatFits(in: .horizontal)`: a wide variant (name • age • address on
   one line) and the existing compact vertical variant, sharing the same
   `Button`/state/actions (no duplicated business logic).
5. Wrap the title/button header in `ViewThatFits` (wide: current `HStack`;
   compact: `VStack(alignment: .leading)` with the button below), reusing
   the same `Text`/`Button` — trivial but keeps header usable at the new
   smaller minimum.
6. AddPatientView: add `.fixedSize(horizontal: false, vertical: true)` to
   the four inline validation-error `Text` views (L27-29, 41-43, 130-132,
   152-154) so long validation messages wrap instead of relying on implicit
   behavior; `Form` itself is already responsive, no other change needed
   there.

### Phase C — PatientDetailView / PatientHistoryDetailView

Files:

- `src/WOA/Views/PatientDetailView.swift` (contains `PatientDetailView`,
  `ConsultoPatientDetailView`, `TreatmentDetailEditView`,
  `EvaluationDetailEditView`, `ExamDetailEditView`)
- `src/WOA/Views/PatientHistoryDetailView.swift`

Problems found:

- Repeated header pattern: `HStack(alignment: .top) { info VStack; Spacer();
edit/delete or save/cancel buttons }` in `PatientDetailView.header` (L62),
  `ConsultoPatientDetailView.header` (~L253), and equivalent blocks in
  `TreatmentDetailEditView`/`EvaluationDetailEditView`/`ExamDetailEditView`,
  plus `PatientHistoryDetailView` header (~L39). Risk of button/text
  overlap at narrow widths.
- `summaryRow` (PatientDetailView, used for both consultations and history
  rows) hard-codes `.frame(width: 130, alignment: .leading)` for the date
  column (L137/144 area) — doesn't shrink or reflow.
- `.frame(maxWidth: 760, alignment: .leading)` (PatientDetailView L43,
  ConsultoPatientDetailView L166-ish) and `.frame(maxWidth: 560, ...)` used
  on the add/edit forms (Treatment/Evaluation/Exam) — these are readability
  caps (they only limit *growth*, they don't block shrinking), so they're
  kept but turned into named `LayoutMetrics` constants instead of bare
  literals.
- Duplicated success/error confirmation card markup across
  `PatientHistoryDetailView` and the edit views.

Changes:

1. Add a private `LayoutMetrics` enum (per file) with
   `readableContentMaxWidth = 760`, `formMaxWidth = 560`,
   `dateColumnMinWidth = 100`; replace the bare numeric literals.
2. Extract a private
   `detailHeader(title:subtitle:isEditing:onCancel:onSave:onEdit:onDelete:)`
   builder (reused within `PatientDetailView.swift` by all four structs
   that need it) that renders:
   - wide: existing `HStack(alignment: .top)` (info leading, Spacer,
     buttons trailing)
   - compact: `VStack(alignment: .leading)` with the info block, then an
     `HStack` of the same buttons below
   selected via `ViewThatFits(in: .horizontal)`. No new state — the same
   bindings/closures already owned by each view are passed straight
   through.
3. Apply the same `ViewThatFits` wide/compact header treatment locally
   inside `PatientHistoryDetailView.swift` (kept as a separate, file-local
   builder per the "no shared cross-file component" scope decision).
4. Rework `summaryRow` to use `ViewThatFits`: wide row keeps the current
   `HStack` with
   `.frame(minWidth: LayoutMetrics.dateColumnMinWidth, alignment: .leading)`
   (min instead of fixed width) on the date `Text`; compact row stacks date
   above the description `Text` in a `VStack(alignment: .leading)`. Applied
   consistently in the treatments/evaluations/exams row renderers in
   `ConsultoPatientDetailView` too (same shape, currently inlined
   per-section rather than calling `summaryRow` — will be unified to call
   one shared private row builder to remove the duplication already flagged
   by Explore).
5. Extract the repeated success/error confirmation card (`Image` + `Text`
   on colored rounded background) into one private builder reused by
   `PatientHistoryDetailView` and the three edit views, removing the
   currently duplicated markup — pure presentation, no behavior change.
6. Leave `760`/`560` as maximum-width readability caps (now named
   constants); do not add a `minWidth` there beyond what
   `ViewThatFits`/flexible frames already provide, since forcing a minWidth
   would fight the compact header changes above.

## Verification

1. Build: run the existing Xcode build task/command discovered from
   `codemagic.yaml` or `WOA.xcodeproj` scheme (confirm exact command before
   Phase 5 — likely
   `xcodebuild -scheme WOA -destination 'platform=macOS' build`).
2. Run existing unit/UI tests if any exist under a `Tests` target (search
   workspace for `*Tests.swift` — none currently listed under `src/`,
   confirm during implementation).
3. Manual verification via SwiftUI Previews at three window widths per
   changed view: compact (~380-420pt, at/near existing minimums), standard
   (~700pt), wide (~1000pt+) — add these previews where missing
   (`PatientsSearchView`, `PatientDetailView`, `ConsultoPatientDetailView`,
   `PatientHistoryDetailView`, `TreatmentDetailEditView`,
   `EvaluationDetailEditView`, `ExamDetailEditView` currently have none).
4. Confirm no state resets: verify `searchText`, `results`, form field
   values, `isEditing`/`isAttributesExpanded`/etc., and `validationErrors`
   are untouched when only the `ViewThatFits` branch changes (they're bound
   through existing `@Published`/`@State`, no new state introduced).

## Decisions

- No shared/cross-file `LayoutMetrics` or layout-component module — each
  view file keeps its own private constants/helpers, per user's scope
  choice ("root view + direct children only").
- `ViewThatFits` chosen over `GeometryReader` or numeric breakpoints for all
  wide/compact header and row variants, per the instruction's strategy
  priority order — avoids inventing arbitrary breakpoint widths.
- `760`/`560` maxWidth caps are kept (renamed, not removed) since they act
  as readability limits on wide windows, not narrow-window blockers.
- SettingsView's `minWidth: 420, minHeight: 320` and PatientsSearchView's
  `minWidth: 520, minHeight: 420` are kept as the usable-size floor per
  "Minimum Size and Scrolling" rule; only added
  `maxWidth/maxHeight: .infinity` so the views actually grow into larger
  windows.

## Further Considerations

1. Result-row wide variant in PatientsSearchView (name • age • address
   inline) — recommend building it, but if the current compact-only
   vertical layout is preferred to avoid touching visual identity, it can
   be dropped and only the fixed `TextField`/`ScrollView` sizing fixed
   (Option A: full Phase B row change / Option B: sizing-only, skip row
   variant).
2. PatientHistoryDetailView's header (not fully read past line 60) — plan
   assumes the same `HStack(alignment:.top)` shape as the other detail
   headers based on Explore's report; will confirm exact lines before
   editing.
