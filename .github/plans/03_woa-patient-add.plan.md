# Plan: Add New Patient Feature

**Prompt:** `03_woa-patient-add.prompt.md`

**Objective:** Enable users to create new patient records in the database through a dedicated form accessible from the PatientsSearchView. Form includes required fields (nome, cognome), optional fields, province dropdown from lookup table, date picker with manual input option, real-time validation, and post-submission navigation with success/error feedback.

---

## Scope

### In Scope
- AddPatientView with form inputs and real-time validation
- AddPatientViewModel managing form state and submission logic
- PatientCreateRequest and LookupProvince models
- Extended PatientRepository with createPatient() and fetchProvinces() methods
- Province dropdown populated from lkp_provincia table
- Dual date input: DatePicker + manual text field (dd/MM/yyyy format)
- Inline validation errors displayed under fields
- Success alert dialog with automatic navigation back to search
- Error handling with user-friendly messages, form remains open on error
- Navigation from PatientsSearchView via sheet modal
- Logging of patient creation attempts and failures

### Out of Scope
- Batch patient import
- Patient editing (update/delete operations)
- Duplicate patient detection or constraints
- Advanced date validation (e.g., age restrictions)
- Custom form field components
- Unit or integration tests
- Email/phone format validation on optional fields

---

## Architecture Overview

### MVVM Pattern
```
AddPatientView (SwiftUI)
    ↓
AddPatientViewModel (@MainActor, observable state, validation, submission)
    ↓
PatientRepository (data access, insert and lookup queries)
    ↓
SQLiteConnection (persistence)
```

### Directory Structure (additions)
```
src/WOA/
├── Models/
│   ├── PatientCreateRequest.swift         [NEW] Form input model
│   ├── LookupProvince.swift               [NEW] Province dropdown model
│   └── ...existing models
├── ViewModels/
│   ├── AddPatientViewModel.swift          [NEW] Form state and validation
│   └── ...existing viewmodels
├── Views/
│   ├── AddPatientView.swift               [NEW] Form view
│   ├── PatientsSearchView.swift           [MODIFIED] Add "Add Patient" button
│   └── ...existing views
├── Repositories/
│   ├── PatientRepository.swift            [MODIFIED] Add createPatient() and fetchProvinces()
│   └── ...existing repositories
└── ...
```

---

## Implementation Phases

### Phase 1: Data Models & Repository

#### 1.1 Create PatientCreateRequest Model [Models/PatientCreateRequest.swift]

**Purpose:** Stores form input state with same fields as paziente table.

**Structure:**
```swift
struct PatientCreateRequest {
    var nome: String = ""
    var cognome: String = ""
    var professione: String?
    var indirizzo: String?
    var citta: String?
    var telefono: String?
    var cellulare: String?
    var prov: String?           // Stores sigla (AG, MI, etc.)
    var cap: String?
    var email: String?
    var data_nascita: Date?
}
```

**Notes:**
- All fields are Strings initially (form inputs); ViewModel handles conversion to Date for data_nascita
- No validation logic in the model; defer all validation to ViewModel
- Implements Codable if future persistence in UserDefaults is needed

#### 1.2 Create LookupProvince Model [Models/LookupProvince.swift]

**Purpose:** Lightweight model for province dropdown, representing lkp_provincia table rows.

**Structure:**
```swift
struct LookupProvince: Identifiable, Hashable {
    let id = UUID()
    let sigla: String          // AG, MI, etc.
    let descrizione: String    // AGRIGENTO, MILANO, etc.
}
```

**Notes:**
- Identifiable for use in Picker
- Hashable for use in @State/selection bindings
- sigla is the value stored in paziente.prov; descrizione is displayed to user

#### 1.3 Extend PatientRepository with createPatient() [Repositories/PatientRepository.swift]

**New Method:**
```swift
static func createPatient(
    _ request: PatientCreateRequest,
    databaseFileURL: URL
) throws -> Int
```

**Implementation Details:**
- Opens SQLiteConnection with readOnly: false
- Builds parametrized INSERT statement into paziente table
- Maps all fields from request to SQL parameters, NULL for empty optionals
- Returns sqlite3_last_insert_rowid() as inserted patient ID
- Throws SQLiteConnectionError on any failure (DB locked, schema mismatch, etc.)
- Logs attempt: `AppLogger.info("Adding patient: \(request.nome) \(request.cognome)")`
- Logs error: `AppLogger.error("Failed to add patient: \(error.localizedDescription)")`

**SQL Pattern:**
```sql
INSERT INTO paziente (
    cognome, nome, professione, indirizzo, citta, telefono, cellulare, prov, cap, email, data_nascita
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
```

#### 1.4 Add fetchProvinces() to PatientRepository [Repositories/PatientRepository.swift]

**New Method:**
```swift
static func fetchProvinces(databaseFileURL: URL) throws -> [LookupProvince]
```

**Implementation Details:**
- Opens SQLiteConnection with readOnly: true
- Queries lkp_provincia table: SELECT sigla, descrizione ORDER BY descrizione
- Maps each row to LookupProvince(sigla:, descrizione:)
- Returns sorted array (109 Italian provinces + EE for STATO ESTERO)
- Throws SQLiteConnectionError if table missing or query fails
- Called once on ViewModel initialization, result cached

**SQL:**
```sql
SELECT sigla, descrizione FROM lkp_provincia ORDER BY descrizione COLLATE NOCASE
```

---

### Phase 2: ViewModel

#### 2.1 Create AddPatientViewModel [ViewModels/AddPatientViewModel.swift]

**Class Declaration:**
```swift
@MainActor final class AddPatientViewModel: ObservableObject {
    let databaseFileURL: URL
    
    @Published var formData: PatientCreateRequest = .init()
    @Published var selectedProvince: LookupProvince?
    @Published var allProvinces: [LookupProvince] = []
    @Published var isSubmitting: Bool = false
    @Published var validationErrors: [String: String] = [:]
    @Published var globalErrorMessage: String?
    @Published var didSubmitSuccessfully: Bool = false
    
    init(databaseFileURL: URL) {
        self.databaseFileURL = databaseFileURL
        Task {
            await loadProvinces()
        }
    }
    
    // MARK: - Methods
    func loadProvinces() async { ... }
    func validateField(_ fieldName: String) -> String? { ... }
    func submitForm() async { ... }
}
```

**State Properties:**
- `formData`: Mutable form input, bound directly to TextFields in view
- `selectedProvince`: Current province selection in picker
- `allProvinces`: Cached list of LookupProvince for dropdown (populated on init)
- `isSubmitting`: True during DB insertion, disables submit button
- `validationErrors`: Dictionary mapping field name to error message; nil or "" means valid
- `globalErrorMessage`: Non-field error (e.g., "Database connection failed")
- `didSubmitSuccessfully`: Set to true on successful insert, triggers success alert and dismissal

**Method: loadProvinces() async**
- Called in init() via Task
- Calls PatientRepository.fetchProvinces(databaseFileURL:)
- On success: populate allProvinces, log "✅ Loaded X provinces"
- On error: log error, keep allProvinces empty, disable prov field in view

**Method: validateField(_ fieldName: String) -> String?**
- Called on onChange from TextFields, returns error message or nil
- **nome validation:**
  - If empty: return "First name is required"
  - If length < 2 chars: return "First name must be at least 2 characters"
  - Otherwise: return nil
- **cognome validation:**
  - If empty: return "Last name is required"
  - If length < 2 chars: return "Last name must be at least 2 characters"
  - Otherwise: return nil
- **prov validation (only on submit attempt):**
  - If nil or empty: return "Province is required" (only checked during submitForm, not onChange)
  - Otherwise: return nil
- **data_nascita validation:**
  - If nil: return nil (optional field)
  - If date > today: return "Date of birth cannot be in the future"
  - Otherwise: return nil
- **All other fields:** return nil (no validation per user decision)

**Method: submitForm() async**
- Validates nome, cognome, prov, data_nascita
- Populates validationErrors dict: if validateField returns error, set validationErrors[fieldName] = error
- If validationErrors.count > 0: return early without submission
- Set isSubmitting = true
- Call PatientRepository.createPatient(formData, databaseFileURL:)
- On success:
  - Log: `AppLogger.info("✅ Patient created successfully: ID=\(patientID)")`
  - Set didSubmitSuccessfully = true (triggers success alert in view, then dismissal)
- On error:
  - Log: `AppLogger.error("❌ Failed to add patient: \(error.localizedDescription)")`
  - Set globalErrorMessage = error.localizedDescription
  - Remain on form (view does not dismiss)
- Finally: Set isSubmitting = false

---

### Phase 3: View

#### 3.1 Create AddPatientView [Views/AddPatientView.swift]

**View Declaration:**
```swift
struct AddPatientView: View {
    @StateObject private var viewModel: AddPatientViewModel
    @Environment(\.dismiss) var dismiss
    
    init(databaseFileURL: URL) {
        _viewModel = StateObject(wrappedValue: AddPatientViewModel(databaseFileURL: databaseFileURL))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Sections and fields here
            }
            .navigationTitle("Add New Patient")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
```

**Layout Structure:**

1. **Header:** Title "Add New Patient"

2. **Required Section:**
   - **Nome TextField**
     - Placeholder: "First name *"
     - Binding: `$viewModel.formData.nome`
     - onChange: triggers `viewModel.validationErrors["nome"] = viewModel.validateField("nome") ?? ""`
     - Error message below (red, .caption font):
       ```swift
       if let error = viewModel.validationErrors["nome"], !error.isEmpty {
           Text(error).font(.caption).foregroundStyle(.red)
       }
       ```
   - **Cognome TextField**
     - Placeholder: "Last name *"
     - Binding: `$viewModel.formData.cognome`
     - onChange: triggers validation as above
     - Error display same as nome

3. **Optional Section:**
   - **Professione, Indirizzo, Citta, Telefono, Cellulare, Cap, Email TextFields**
     - All optional fields, no validation, no error display
     - Bindings to corresponding formData properties
     - Placeholder text for each field

4. **Province Picker:**
   - Label: "Province *"
   - Binding: `$viewModel.selectedProvince`
   - Picker options: viewModel.allProvinces.map { $0.descrizione }
   - Placeholder tag: nil, displays "Select Province" when unselected
   - onChange: update formData.prov = selectedProvince?.sigla ?? ""
   - Error message below if validation fails

5. **Date of Birth Section:**
   - **DatePicker**
     - Label: "Date of Birth"
     - Binding to parsed viewModel.formData.data_nascita
     - Style: .date (date only, no time picker)
   - **Manual TextField**
     - Placeholder: "dd/MM/yyyy"
     - Accepts manual text input in "dd/MM/yyyy" format
     - onChange: Parse with DateFormatter(dateFormat: "dd/MM/yyyy"), update formData.data_nascita
     - If parse fails: show error "Invalid date format (use dd/MM/yyyy)"
   - Error message below if date is in future

6. **Global Error Display:**
   - If viewModel.globalErrorMessage != nil:
     ```swift
     Text(viewModel.globalErrorMessage ?? "")
         .font(.callout)
         .foregroundStyle(.red)
         .padding(.vertical)
     ```

7. **Button Row:**
   - **Cancel Button:** `dismiss()` on tap
   - **Add Patient Button:**
     - Title: "Add Patient"
     - Disabled if: `isSubmitting || !validationErrors.isEmpty`
     - Action: `Task { await viewModel.submitForm() }`

**Post-Submission Flow:**

- Monitor viewModel.didSubmitSuccessfully
- If true, show alert:
  ```swift
  .alert("Success", isPresented: .constant(viewModel.didSubmitSuccessfully)) {
      Button("OK") { dismiss() }
  } message: {
      Text("Patient added successfully.")
  }
  ```
- On OK button tap: dismiss sheet (return to PatientsSearchView)

#### 3.2 Update PatientsSearchView [Views/PatientsSearchView.swift]

**Changes:**
- Add @State var showAddPatientSheet: Bool = false at top of View
- Add "Add Patient" button above search field:
  ```swift
  Button(action: { showAddPatientSheet = true }) {
      Label("Add Patient", systemImage: "person.badge.plus")
  }
  ```
- Add sheet modifier:
  ```swift
  .sheet(isPresented: $showAddPatientSheet) {
      AddPatientView(databaseFileURL: databaseURL)
  }
  ```
- (Optional) On sheet dismissal, refresh search results (defer if not required)

---

### Phase 4: Integration & Error Handling

#### 4.1 Error Handling Strategy

- **LocalizedError pattern:** Use existing SQLiteConnectionError for DB failures
- **Validation errors:** Stored in ViewModel.validationErrors[fieldName]
- **User-facing messages:**
  - Display field validation errors under each field in red
  - Display global errors (DB failures) in red above buttons
  - Show success alert only on successful insertion

#### 4.2 Logging

- **Info level:**
  ```swift
  AppLogger.info("Adding patient: \(formData.nome) \(formData.cognome)")
  AppLogger.info("✅ Patient created successfully: ID=\(patientID)")
  ```
- **Error level:**
  ```swift
  AppLogger.error("❌ Failed to add patient: \(error.localizedDescription)")
  ```
- **Never use print()** — only OSLog via AppLogger

#### 4.3 Date Handling

- **DateFormatter setup:**
  ```swift
  let formatter = DateFormatter()
  formatter.dateFormat = "dd/MM/yyyy"
  formatter.locale = Locale(identifier: "it_IT")  // Italian locale
  ```
- **Manual parsing:** TextField onChange parses string → Date
- **Display:** Show DatePicker + TextField, both synced to formData.data_nascita
- **Timezone:** Treat all DOB dates as local (no UTC conversion)
- **Validation:** Check date <= today(), reject future dates

---

## File Summary

| File | Type | Action | Purpose |
|------|------|--------|---------|
| `src/WOA/Models/PatientCreateRequest.swift` | New | Create | Form input model with all paziente fields |
| `src/WOA/Models/LookupProvince.swift` | New | Create | Lightweight province model for dropdown |
| `src/WOA/Repositories/PatientRepository.swift` | Modified | Extend | Add createPatient() and fetchProvinces() methods |
| `src/WOA/ViewModels/AddPatientViewModel.swift` | New | Create | Form state, validation, submission logic |
| `src/WOA/Views/AddPatientView.swift` | New | Create | Complete form UI with validation display |
| `src/WOA/Views/PatientsSearchView.swift` | Modified | Update | Add "Add Patient" button and sheet navigation |

---

## Verification Checklist

### 1. Model Creation
- [ ] PatientCreateRequest instantiates with all fields initialized
- [ ] LookupProvince instantiates with sigla and descrizione
- [ ] Both models conform to expected protocols (Codable, Identifiable, etc.)

### 2. Repository Functions
- [ ] PatientRepository.fetchProvinces() returns 110 provinces (109 Italian + EE)
- [ ] PatientRepository.createPatient() inserts patient and returns ID
- [ ] Errors thrown on missing nome/cognome
- [ ] Logs appear in OSLog for success and failure cases

### 3. ViewModel Validation
- [ ] validateField("nome") with "" returns error
- [ ] validateField("nome") with "A" returns error (min 2)
- [ ] validateField("nome") with "Ab" returns nil (valid)
- [ ] validateField("cognome") follows same rules
- [ ] validateField("data_nascita") with future date returns error
- [ ] validateField("prov") only checked during submitForm, not onChange
- [ ] submitForm() populates validationErrors dict on validation failure
- [ ] submitForm() calls PatientRepository.createPatient() on success
- [ ] didSubmitSuccessfully triggers alert and dismissal

### 4. UI/Integration Flow
- [ ] Launch app, configure database, navigate to PatientsSearchView
- [ ] Click "Add Patient" button → AddPatientView sheet appears
- [ ] Fill nome and cognome only → form is valid
- [ ] Click "Add Patient" button → success alert appears
- [ ] Click "OK" on alert → sheet closes, return to PatientsSearchView
- [ ] Search for newly added patient → result appears in search results
- [ ] Try adding with missing nome → validation error appears under nome field, form does not submit
- [ ] Try entering invalid date format → error appears under date field
- [ ] Try entering future date → validation error appears under date field
- [ ] Select province from dropdown → formData.prov updated with sigla

### 5. Error Scenarios
- [ ] Database file inaccessible → globalErrorMessage displays in red, sheet remains open
- [ ] Province fetch fails on load → log error, allProvinces stays empty, prov field disabled
- [ ] Duplicate patient with same name → database operation succeeds (allow duplicates)
- [ ] All validation errors clear after fixing field values

---

## User Decisions (Implemented)

- ✅ **Form validation:** Inline (real-time) under each field as user types
- ✅ **Date input:** Separate DatePicker + manual TextField accepting `dd/MM/yyyy`
- ✅ **Province display:** Descrizione (AGRIGENTO, MILANO) displayed; sigla (AG, MI) stored
- ✅ **Success notification:** Alert dialog with confirmation, then automatic dismissal
- ✅ **Optional field validation:** No format validation on optional fields (email, phone, etc.)
- ✅ **Access point:** AddPatientView accessible only from PatientsSearchView via sheet button

---

## Key Design Decisions

1. **Sheet Modal Navigation** — Reuses existing pattern from PatientsSearchView for consistency
2. **Real-time Validation** — onChange callbacks on TextFields, no debouncing required for local validation
3. **Province Sigla Storage** — UI displays descrizione, database stores sigla to match schema
4. **No Async Validation** — All validation runs synchronously (no duplicate-check API calls)
5. **Timezone-Agnostic Dates** — Date of birth stored as local date, no UTC conversion
6. **Duplicate Patients Allowed** — No unique constraint on (nome, cognome); application allows same name records
7. **Single-Use SQLiteConnection** — Follows existing pattern, not pooled
8. **Null Handling** — Empty optional fields stored as NULL in database, not empty strings
9. **Separate Date Inputs** — DatePicker for clicking, TextField for manual entry; both synced to formData.data_nascita
10. **Error Display Strategy** — Field errors below each field, global errors above buttons, form stays open on error

---

## Assumptions

- SQLite library and SQLiteConnection wrapper are fully functional (no changes needed)
- lkp_provincia table exists and contains all 109 provinces (verified in schema)
- paziente table schema matches requirements (no missing or extra columns)
- App runs on macOS with Sandbox enabled (no path or permission issues)
- User will input dates in dd/MM/yyyy format consistently
- Duplicate patients are acceptable (no uniqueness constraint enforced)

---

## Further Considerations

None identified at planning stage. All requirements are straightforward and leverage existing architecture patterns. Date handling is the most complex element (dual input + parsing), but uses standard SwiftUI/Foundation APIs already in use elsewhere in the codebase.
