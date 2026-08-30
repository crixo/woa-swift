# Plan: Patient Search

## Objective
Allow users to search for patients in the application database by name and display the matching results with age and address information. The implementation must maintain the current architecture, use the existing MVVM pattern, and preserve the first-run database selection flow.

## Context
The WOA Application must comply with the rules and guidelines defined in the architecture prompt and use the existing SQLite database schema. The `paziente` table contains the patient records, including `nome`, `cognome`, `data_nascita`, `indirizzo`, `citta`, `prov`, and related fields.

## Requirements
1. Search must be performed against `nome` and `cognome` in the `paziente` table.
2. Matching is case-insensitive and supports partial matches anywhere in the value.
3. The search begins only after the user enters at least 3 characters.
4. Results are displayed in a list with the following fields:
   - `nome`
   - `cognome`
   - age computed from `data_nascita`
   - address built from `indirizzo`, `citta`, and the province description
5. A result counter shows the number of matches found.
6. Each result includes a link/action to view the patient details in a popup for now.
7. This feature must be reachable from the database-connected screen after database selection/import.

## Architecture
The application follows this structure:

View
ViewModel
Service
Repository
Storage

The feature should follow the same pattern and avoid SQL or file access in the view layer.

## Scope
### In Scope
- Search view and search results list
- Patient repository query logic
- Search view model with validation and async updates
- Pop-up patient details presentation
- Navigation from the connected database screen
- Age calculation and address formatting

### Out of Scope
- Full patient CRUD
- New database migration unless schema changes are required
- New persistent settings beyond standard app state

## Proposed Components
### Model
Add a lightweight patient result model that contains:
- `id`
- `nome`
- `cognome`
- `dataNascita: Date?`
- `indirizzo: String?`
- `citta: String?`
- `prov: String?`
- computed `age: Int?`
- computed `address: String`

This should be a UI-friendly representation rather than a full domain model.

### Repository
Create a `PatientRepository` with a method such as:
- `searchPatients(query: String, fileURL: URL) throws -> [PatientSearchResult]`

The SQL should use:
- case-insensitive comparison
- `LIKE` with wildcard padding
- matching against both `nome` and `cognome`
- filtering for strings longer than or equal to 3 characters

Example pattern:
- `LOWER(nome) LIKE ? OR LOWER(cognome) LIKE ?`

### ViewModel
Create `PatientsSearchViewModel` with the following responsibilities:
- maintain `searchText`
- maintain `results: [PatientSearchResult]`
- maintain `isSearching`
- maintain `selectedPatient: PatientSearchResult?`
- enforce minimum search length of 3 characters
- call repository logic asynchronously
- update result count
- open/close details popup

### View
Create `PatientsSearchView` with the following UI:
- text field for the search term
- validation label or hidden behavior for short search values
- result count text such as `X results found`
- list of patient rows
- each row shows:
  - patient full name
  - age
  - address
- a button or link labelled `View details`
- a popup sheet or alert that displays the patient details

## Navigation
From the connected database screen, add a button or navigation action such as `Patients Search` that opens the new `PatientsSearchView`.

This should be added in the existing connected-state screen in `SettingsView`, without altering the database configuration flow or selector behavior.

## SQL Considerations
The current schema uses `prov` as a two-letter province code and `citta` and `indirizzo` as text fields. To show a user-friendly address, the implementation may either:
- display the `prov` code directly, or
- join against `lkp_provincia` to show the full province description.

For usability, a join against `lkp_provincia` is preferred because the requirement mentions `provincia` rather than `prov`.

## Age Calculation
Age should be computed on the fly from `data_nascita` using the current calendar date and the patient’s birth date. If the date is missing or invalid, the UI should gracefully display `Age unavailable` or omit the age field.

## Error Handling
The feature must not crash on malformed dates or empty result sets. Errors from the data layer should be logged through the existing `AppLogger` and surfaced in the view model in a friendly way.

## Implementation Notes
- Views stay presentation-only.
- SQL queries remain in the repository layer.
- The repository should use the existing `SQLiteConnection` wrapper.
- The feature should work with the current App Support database configuration and must not require any new user-facing storage path.
- No new migration should be required unless the schema itself is extended in a future prompt.

## Verification Checklist
- Search starts only when at least 3 characters are typed
- Search is case-insensitive against `nome` and `cognome`
- Partial matches return expected results
- Each result displays name, age, and address
- Counter reflects the number of results
- Selected patient details show in the popup
- Connected database flow still works without regressions

## Recommendation
No prompt change is strictly necessary because the architecture prompt already provides the schema and the feature aligns with the current MVVM and repository approach. If additional user-flow clarification is desired later, the prompt could explicitly say that the feature should be accessible from the main connected screen via a dedicated navigation action.
