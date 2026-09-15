# Plan: Split PatientDetailView.swift / PatientDetailViewModel.swift

Per `.github/instructions/swift-platform.instructions.md`, the 1:1 View/file rule is currently violated in two monolithic files: `PatientDetailView.swift` (11 structs) and `PatientDetailViewModel.swift` (11 classes).

## Classification of current structs/classes

| Struct/Class | Current file | Rule verdict |
|---|---|---|
| `PatientDetailView` | PatientDetailView.swift | Primary destination — stays as file anchor |
| `PatientHistoryDetailView` | PatientDetailView.swift | Read-only, reachable only via `onOpenHistory` callback from its parent → **valid sub-view**, may stay |
| `ConsultoPatientDetailView` | PatientDetailView.swift | Independently routed (`.consultoDetail`), has its own edit/expand state and 3 child lists → **must split** |
| `AddConsultationView` | PatientDetailView.swift | "Add X" form → **must split** |
| `AddRemoteHistoryView` | PatientDetailView.swift | "Add X" form → **must split** |
| `AddTreatmentView` | PatientDetailView.swift | "Add X" form → **must split** |
| `TreatmentDetailEditView` | PatientDetailView.swift | Independently routed (`.treatmentDetail`), full edit-in-place page → **must split** |
| `AddEvaluationView` | PatientDetailView.swift | "Add X" form → **must split** |
| `EvaluationDetailEditView` | PatientDetailView.swift | Independently routed (`.evaluationDetail`) → **must split** |
| `AddExamView` | PatientDetailView.swift | "Add X" form → **must split** |
| `ExamDetailEditView` | PatientDetailView.swift | Independently routed (`.examDetail`) → **must split** |

Same reasoning applies 1:1 to the matching ViewModels — `RemoteHistoryDetailViewModel` is the only true sub-ViewModel (backs the sub-view `PatientHistoryDetailView`); every other class must move to its own file, keeping the `<ViewName>ViewModel` naming convention.

## Proposed file-system hierarchy

```
src/WOA/Views/
├── PatientDetailView.swift          (PatientDetailView + PatientHistoryDetailView)
├── ConsultoDetailView.swift         (ConsultoPatientDetailView)              [NEW]
├── AddConsultationView.swift        (AddConsultationView)                   [NEW]
├── AddRemoteHistoryView.swift       (AddRemoteHistoryView)                  [NEW]
├── AddTreatmentView.swift           (AddTreatmentView)                      [NEW]
├── TreatmentDetailEditView.swift    (TreatmentDetailEditView)               [NEW]
├── AddEvaluationView.swift          (AddEvaluationView)                     [NEW]
├── EvaluationDetailEditView.swift   (EvaluationDetailEditView)              [NEW]
├── AddExamView.swift                (AddExamView)                          [NEW]
├── ExamDetailEditView.swift         (ExamDetailEditView)                    [NEW]
├── AddPatientView.swift             (unchanged)
├── DatabaseSelectorView.swift       (unchanged)
├── PatientsSearchView.swift         (unchanged)
├── SettingsView.swift               (unchanged — router only)
└── TableStatusView.swift            (unchanged)

src/WOA/ViewModels/
├── PatientDetailViewModel.swift     (PatientDetailViewModel + RemoteHistoryDetailViewModel)
├── ConsultoDetailViewModel.swift    (ConsultoDetailViewModel)                [NEW]
├── ConsultationCreateViewModel.swift(ConsultationCreateViewModel)            [NEW]
├── RemoteHistoryCreateViewModel.swift(RemoteHistoryCreateViewModel)          [NEW]
├── TreatmentCreateViewModel.swift   (TreatmentCreateViewModel)               [NEW]
├── TreatmentEditViewModel.swift     (TreatmentEditViewModel)                 [NEW]
├── EvaluationCreateViewModel.swift  (EvaluationCreateViewModel)              [NEW]
├── EvaluationEditViewModel.swift    (EvaluationEditViewModel)                [NEW]
├── ExamCreateViewModel.swift        (ExamCreateViewModel)                    [NEW]
├── ExamEditViewModel.swift          (ExamEditViewModel)                     [NEW]
├── AddPatientViewModel.swift        (unchanged)
├── DatabaseSelectorViewModel.swift  (unchanged)
├── PatientsSearchViewModel.swift    (unchanged)
└── SettingsViewModel.swift          (unchanged)
```

**Net result:** 9 new View files + 9 new ViewModel files; `PatientDetailView.swift`/`PatientDetailViewModel.swift` shrink to just the one legitimate 2-struct exception each (`PatientDetailView`+`PatientHistoryDetailView`, `PatientDetailViewModel`+`RemoteHistoryDetailViewModel`).

**Follow-up requirements if implemented:**
- `SettingsView.swift` only references types by name (single module, no imports needed) — no changes required there beyond the split itself.
- Per `copilot-instructions.md`'s Xcode Project Management rule, every new file must get PBXFileReference + PBXBuildFile + group + Sources build phase entries in `project.pbxproj`.
- Consider renaming `ConsultoPatientDetailView` → `ConsultoDetailView` for naming symmetry with the file, but that's optional/cosmetic.
