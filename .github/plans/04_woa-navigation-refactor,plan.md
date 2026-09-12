## Plan: Inline Navigation Refactor

Migrate the existing feature sheets to one root-owned macOS SwiftUI navigation stack while preserving database, search, patient-detail, and add-patient behavior. `SettingsView` will own a typed route path and shared Home/Back/related navigation chrome; feature views will remain presentation-focused and will receive route actions or bindings rather than owning presentation booleans.

**Steps**

### Phase 1: Inventory and plan alignment
1. Record the Step 1 inventory before implementation:
   - `src/WOA/WOA.swift` — app-level `WindowGroup` containing `SettingsView`; legitimate single application window; out of scope.
   - `src/WOA/Views/SettingsView.swift` — `.sheet(isPresented: $showPatientSearch)` presents `PatientsSearchView`; full feature view; in scope.
   - `src/WOA/Views/PatientsSearchView.swift` — `.sheet(item: $viewModel.selectedPatient)` presents `PatientDetailsSheet`; full detail feature; in scope.
   - `src/WOA/Views/PatientsSearchView.swift` — `.sheet(isPresented: $showAddPatientSheet)` presents `AddPatientView`; full feature form; in scope.
   - `src/WOA/Views/DatabaseSelectorViewModel.swift` — `NSOpenPanel`; legitimate system file picker; out of scope.
   - `src/WOA/Views/AddPatientView.swift` — success `.alert`; legitimate transient confirmation; retain.
   - No `.popover`, `openWindow`, or `NSWindowController` occurrences were found under `src/**/*.swift`.
2. Create `.github/plans/03.1_woa-navigation-refactor.plan.md` during implementation, using this migration plan as the source of truth. Explicitly supersede the popup/sheet navigation wording in `.github/plans/02_woa-patients-search.plan.md` and `.github/plans/03_woa-patient-add.plan.md`; do not rewrite unrelated historical plans unless the repository convention requires a short cross-reference.

### Phase 2: Root navigation model and shared chrome
3. Modify `src/WOA/Views/SettingsView.swift` to become the sole navigation owner while retaining the current loading, database import, connected-status, and re-selection behavior.
4. Add a small typed route representation in the view layer or a dedicated navigation ViewModel, following the existing MVVM boundary. The route must carry:
   - Patients search with the configured database path.
   - Add patient with the configured database URL.
   - Patient details with the selected `PatientSearchResult`.
5. Replace `showPatientSearch` and the connected-state sheet with a `NavigationStack` and root-owned path/selection. Use `NavigationDestination` to render search, details, and add-patient inline in the main content/detail area. Preserve the existing app-level `WindowGroup` in `WOA.swift`; do not add another scene or window.
6. Put Home, Back, and related-view controls in persistent root-owned toolbar/sidebar navigation chrome. Home clears the route path to the connected landing view. Back removes the last route and therefore returns details/add to search and search to the connected landing view. Related links include Patients Search from the connected screen, View Details and Add Patient from search, and a return/search link from the detail and add contexts as appropriate. Keep these controls out of duplicated feature-local navigation logic.
7. Ensure the connected landing view is the route root and that resetting the database also clears the route path so no feature remains visible after configuration is invalidated.

### Phase 3: Migrate search, details, and add-patient views
8. Modify `src/WOA/Views/PatientsSearchView.swift` to remove `showAddPatientSheet` and both sheet modifiers. Preserve search fields, result rendering, error handling, and `PatientsSearchViewModel` ownership. Replace the Add Patient button action with the route callback supplied by the root.
9. Convert the private `PatientDetailsSheet` into an inline detail view/route destination without changing the displayed `PatientSearchResult.details` content. Keep the selected patient payload intact; the selection may continue to be represented by `PatientsSearchViewModel.selectedPatient`, but route presentation must be controlled by the root path rather than a sheet binding.
10. Modify `src/WOA/ViewModels/PatientsSearchViewModel.swift` only as needed to expose selected-patient state cleanly for inline routing. Preserve repository calls, async search behavior, minimum query length, result/error state, and existing open/close semantics. Do not touch Services, Repositories, or Storage.
11. Modify `src/WOA/Views/AddPatientView.swift` to remove its dependency on `@Environment(\.dismiss)` for Cancel and successful submission. Add a parent-provided cancel/completion callback or route action. Keep the form, validation, date handling, province loading, submit task, and success alert unchanged in behavior. The success alert's OK action must invoke the callback that returns to Patients Search after confirmation.
12. Avoid nested feature windows or presentation wrappers. If the existing `NavigationStack` inside `AddPatientView` conflicts with the root stack, reduce it to the form content and retain only the necessary title/toolbar presentation so the root owns navigation history and chrome.

### Phase 4: Project and documentation consistency
13. Because this migration modifies existing Swift files and adds no new Swift source file if the route type remains in `SettingsView.swift`, verify `src/WOA.xcodeproj/project.pbxproj` remains consistent. If a dedicated navigation Swift file is introduced, update its `PBXFileReference`, `PBXBuildFile`, group membership, and Sources build phase entries before validation.
14. Update the new refactor plan with the final route design, exact migrated views, preserved transient exceptions, and acceptance results. Do not add TODO placeholders.

**Relevant files**
- `src/WOA/Views/SettingsView.swift` — root navigation container, typed route/path, connected landing route, shared Home/Back/related chrome, and reset behavior.
- `src/WOA/Views/PatientsSearchView.swift` — remove feature sheets, expose route callbacks, and render patient details as an inline destination.
- `src/WOA/ViewModels/PatientsSearchViewModel.swift` — preserve search state and adapt only the selected-patient boundary needed for route navigation.
- `src/WOA/Views/AddPatientView.swift` — replace sheet dismissal with parent-owned cancel/success navigation callbacks while preserving form behavior.
- `src/WOA/WOA.swift` — verify and retain the single app-level `WindowGroup`; no functional change expected.
- `src/WOA/Models/PatientSearchResult.swift` — reuse the existing detail payload and computed display values; no model redesign expected.
- `src/WOA/Views/TableStatusView.swift` and `src/WOA/Views/DatabaseSelectorView.swift` — preserve existing inline onboarding flow and callback patterns.
- `.github/plans/03.1_woa-navigation-refactor.plan.md` — new repository plan required by the output contract.
- `.github/plans/02_woa-patients-search.plan.md` and `.github/plans/03_woa-patient-add.plan.md` — historical plans whose popup/sheet decisions are superseded by the new refactor plan.
- `src/WOA.xcodeproj/project.pbxproj` — update only if implementation creates a new Swift source file.

**Verification**
1. Run the static inventory after implementation: search `src/**/*.swift` for `.sheet`, `.popover`, `WindowGroup`, `openWindow`, and `NSWindowController`. Expected results: only the app-level `WindowGroup`, the allowed `NSOpenPanel`, and the allowed success alert; no feature sheet/popover/window remains.
2. Verify route reachability manually on macOS: connected landing -> Patients Search -> Patient Details -> Back; Patients Search -> Add Patient -> Cancel -> Patients Search; Add Patient successful submit -> Success alert -> OK -> Patients Search; Home from each feature -> connected landing.
3. Verify database configuration/import and re-selection flows still render inline and that re-selection clears any active feature route.
4. Run `xcodebuild -list -project src/WOA.xcodeproj` and a Debug build on a macOS machine with Xcode. The current Windows environment cannot execute Xcode or macOS SwiftUI validation, so implementation should report this limitation if no macOS runner is available.
5. Run the repository's available Swift/Xcode diagnostics or tests, if present; no existing test target was identified during discovery.
6. Confirm no forbidden iOS imports/types/modifiers, no feature `WindowGroup`, no unresolved TODO placeholders, and no changes to Services, Repositories, or Storage.

**Decisions**
- Use a typed `NavigationStack` route/path owned by `SettingsView`, not a `NavigationSplitView`, because the current app has a compact single-root flow and no existing sidebar/selection model.
- Preserve the existing user flow: patient details and add-patient are child routes of search; Back returns to the previous route; successful add still shows the existing confirmation alert and returns to search after OK.
- Home clears the root path and is available through shared root-owned navigation chrome from every loaded feature view.
- Keep `selectedPatient` as the data source for the detail route where practical, but never use its sheet binding as the presentation mechanism.
- Preserve all Service, Repository, Storage, database, validation, search, and form business logic. This is a navigation-wiring remediation only.
- The app-level `WindowGroup`, system `NSOpenPanel`, and transient success `.alert` are explicitly out of scope.

**Further Considerations**
1. A dedicated `NavigationViewModel.swift` would improve separation if the route state grows, but it would require project-file maintenance; keep the initial implementation local to the root unless the route enum/actions become unwieldy.
2. The existing historical plans should remain as provenance unless maintainers prefer adding a short superseded note; the new `03.1` plan is the operative architecture for this remediation.
3. Xcode validation must be performed on macOS or CI because the current Windows host cannot build the macOS target.