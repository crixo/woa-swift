# Plan: Database Selector & Settings UI

**Prompt:** `01_woa-db-selector.prompt.md`

**Objective:** Scaffold the complete Xcode project structure and implement a database selector feature that allows users to select a SQLite database file on first run, validates it, copies it to AppSupport, and displays a settings view with database connection status and table record counts.

---

## Project Scope

### In Scope
- Complete Xcode project scaffolding with MVVM architecture
- Database infrastructure components (DatabaseInstaller, DatabaseValidator, DatabaseMigrator, DatabaseURLProvider)
- Configuration storage in AppSupport (json format)
- SettingsView as app entry point with database selection UI
- TableStatusView for one-time display after successful import
- Table metadata query layer with record counting
- Logging infrastructure using OSLog (console + file)
- Sandbox compliance and entitlements configuration
- Error handling for invalid databases
- Documentation (README with Xcode setup instructions)
- Release build script for packaging

### Out of Scope
- Main application views (patient management, consultations, etc.)
- Patient/Consultation CRUD operations
- Database migrations on existing databases
- Unit/integration tests
- App Store packaging or code signing
- Vapor backend integration
- Multi-user or sync features

---

## Architecture Overview

### MVVM Layer Structure
```
View (SwiftUI)
    ↓
ViewModel (@MainActor, observable state)
    ↓
Service (business logic)
    ↓
Repository (data access, SQLite queries)
    ↓
Storage/SQLite (persistence)
```

### Directory Structure
```
src/WOA/
├── WOA.swift                          # App entry point
├── Models/
│   ├── DatabaseConnection.swift
│   ├── AppSettings.swift
│   └── TableInfo.swift
├── ViewModels/
│   ├── SettingsViewModel.swift
│   └── DatabaseSelectorViewModel.swift
├── Views/
│   ├── SettingsView.swift
│   ├── TableStatusView.swift
│   └── DatabaseSelectorView.swift
├── Services/
│   ├── ConfigurationService.swift
│   ├── DatabaseSelectionService.swift
│   └── DatabaseValidationService.swift
├── Repositories/
│   └── TableRepository.swift
├── Utils/
│   ├── AppPaths.swift
│   ├── AppLogger.swift
│   ├── DatabaseURLProvider.swift
│   ├── DatabaseValidator.swift
│   ├── DatabaseMigrator.swift
│   ├── DatabaseInstaller.swift
│   └── SQLiteConnection.swift
├── Resources/
│   ├── Info.plist
│   └── WOA.entitlements
└── WOA.xcodeproj/
    └── project.pbxproj
```

### Storage & Paths
- **App Database**: `~/Library/Application Support/WOA/database/application.db`
- **Configuration**: `~/Library/Application Support/WOA/configuration/app-settings.json`
- **Logs**: `~/Library/Application Support/WOA/logs/app.log`
- **Cache**: `~/Library/Application Support/WOA/cache/`

---

## Implementation Phases

### Phase 1: Project Scaffolding & Infrastructure Setup

**1.1 Create Xcode project structure**
- Create `src/WOA/` directory with proper folder hierarchy
- Generate `.xcodeproj/project.pbxproj` with:
  - Swift version 5.9+
  - macOS 13+ deployment target
  - Link frameworks: SwiftUI, AppKit, SQLite3, OSLog, Foundation
  - Configure build settings for Release and Debug

**1.2 Implement AppPaths utility**
- Provide methods to get AppSupport directory and subdirectories
- Ensure directories are created on first access
- Handle errors gracefully with logging

**1.3 Implement AppLogger utility**
- Use OSLog for structured logging
- Write logs to both console and file
- Use log style: `✅ Operation succeeded` and `❌ Error: description`
- Log levels: INFO, WARNING, ERROR

**1.4 Implement database infrastructure components**
- `DatabaseURLProvider.swift` — provides path to application database
- `DatabaseValidator.swift` — validates SQLite file (check for core tables)
- `DatabaseMigrator.swift` — scaffolded for future use, currently no-op
- `DatabaseInstaller.swift` — orchestrates full import workflow
- `SQLiteConnection.swift` — manages SQLite connections with error handling

**Dependencies:** AppPaths, AppLogger

---

### Phase 2: Data Models & Configuration

**2.1 Define core data models**
- `DatabaseConnection.swift` — stores path, last validated date, connection status
- `AppSettings.swift` — holds all app configuration (database connection, logging level, theme)
- `TableInfo.swift` — represents table name and record count

**2.2 Implement ConfigurationService**
- Load/save json configuration from `~/Library/Application Support/WOA/configuration/app-settings.json`
- Provide default settings if config doesn't exist
- Handle file I/O errors gracefully

**Dependencies:** AppPaths, AppLogger

---

### Phase 3: Database Query Utilities

**3.1 Implement TableRepository**
- Query database for all tables
- Execute `SELECT COUNT(*) FROM table_name` for each table
- Return array of `TableInfo` sorted alphabetically
- Handle SQL errors with proper logging

**3.2 Expected tables for validation**
- paziente, consulto, esame, trattamento, valutazione, anamnesi_remota, anamnesi_prossima
- Lookup tables: lkp_anamnesi, lkp_esame, lkp_provincia

**Dependencies:** SQLiteConnection, AppLogger

---

### Phase 4: ViewModels & Business Logic

**4.1 Create DatabaseSelectorViewModel**
- `@MainActor` with `@Observable` (or `@StateObject`)
- Properties:
  - `isSelecting: Bool` — NSOpenPanel is open
  - `selectedPath: String?` — user-selected file path
  - `validationError: String?` — error message if validation fails
  - `isImporting: Bool` — import in progress
  - `connectionStatus: String` — "Connected", "Disconnected", "Validating", etc.
- Methods:
  - `selectDatabase()` — present NSOpenPanel, filter for .db files
  - `importDatabase()` — validate + copy + save configuration
  - `validateConnection()` — test existing connection
- Error handling: catch errors, set `validationError`, log to AppLogger

**4.2 Create SettingsViewModel**
- `@MainActor` observable
- Properties:
  - `isConfigured: Bool` — database is configured
  - `connectionStatus: String` — connection state
  - `tableStats: [TableInfo]` — list of tables with counts
  - `allSettings: AppSettings` — all app configuration
  - `isLoading: Bool` — async operation in progress
- Methods:
  - `loadSettings()` — read config from ConfigurationService
  - `testDatabaseConnection()` — async operation to validate connection
  - `refreshTableStats()` — async operation to query table counts
- Use async/await with Task to avoid blocking UI

**Dependencies:** ConfigurationService, TableRepository, DatabaseValidator, AppLogger

---

### Phase 5: Views

**5.1 Create SettingsView (main entry point)**
- App header: "WOA"
- **If database NOT configured:**
  - Show "Database Configuration Required" message
  - Embed DatabaseSelectorView
  - Show error message if import fails
- **If database IS configured:**
  - Show "Database Connection Status: ✅ Connected"
  - Display last validated timestamp
  - Show table list in format: `- paziente (100)`, `- consulto (332)`, etc.
  - Provide "Re-select Database" button for reconfiguration
- Bind to SettingsViewModel state
- Handle loading state with progress indicator

**5.2 Create TableStatusView (one-time display)**
- Title: "Database Import Successful"
- Display table list with record counts (same format as SettingsView)
- Show summary: "X tables found with Y total records"
- Acknowledge button to continue to main app

**5.3 Create DatabaseSelectorView (sub-component)**
- File selection button ("Browse Database File")
- Status indicator (file path or "No file selected")
- Display validation progress ("Validating database...")
- Display error message if validation fails (red text)
- Disable button during import operation

**Dependencies:** ViewModels, relevant Services/Repositories

---

### Phase 6: App Entry & Lifecycle

**6.1 Create App.swift (main entry point)**
- App struct with `@main` decorator
- Initialize AppDelegate for early setup (logging, directory creation)
- On first launch:
  - Check if database is configured via ConfigurationService
  - Route to SettingsView if NOT configured
  - Route to TableStatusView if just imported
  - Route to MainAppView if already configured (scaffold placeholder only)
- Provide SettingsViewModel as environment object
- Handle app lifecycle events (didFinishLaunching, willTerminate)

**6.2 Update Info.plist**
- Set app name, version, build number
- Set CFBundleIdentifier: `com.woa.application`
- Set LSMinimumSystemVersion: macOS 13.0
- Disable document-based app settings if applicable

**6.3 Update WOA.entitlements**
- Enable App Sandbox
- Add entitlements:
  - `com.apple.security.files.user-selected.read-write` — allow user to select files
  - `com.apple.security.app-sandbox` — enable sandboxing
  - `com.apple.security.files.downloads.read-write` — read from Downloads
  - `com.apple.security.files.documents.read-write` — read from Documents (if needed)
- Do NOT add entitlements for unrestricted file system access

**Dependencies:** ConfigurationService, AppLogger

---

### Phase 7: Documentation & Project Files

**7.1 Create comprehensive README.md**
- Project overview
- System requirements (macOS 13+, Xcode 14+)
- Step-by-step Xcode setup:
  1. Open `src/WOA.xcodeproj`
  2. Select scheme "WOA"
  3. Configure signing team
  4. Run or build
- Explanation of App Sandbox configuration
- How to add new files while maintaining directory structure
- Build & package instructions
- Troubleshooting section (common Xcode errors, sandbox issues)
- Include screenshots for key steps if helpful

**7.2 Create build-release.sh script**
- Build app in Release configuration
- Code sign if necessary
- Package into .app bundle
- Create DMG for distribution (optional)
- Log build output to `build-release.log`

**7.3 Generate Xcode project file**
- Create `.xcodeproj/project.pbxproj` with:
  - All source files organized in folder structure
  - Build settings for macOS deployment
  - Linked frameworks (SQLite3, OSLog, etc.)
  - Entitlements file reference
  - Info.plist reference

**Dependencies:** All previous phases

---

## Implementation Order & Parallelization

### Sequential Execution Path (Recommended)
1. **Phases 1–3** (Infrastructure + Models + Queries): ~40% of work
2. **Phases 4–5** (ViewModels + Views): ~40% of work
3. **Phase 6** (App Entry + Configuration): ~10% of work
4. **Phase 7** (Documentation): ~10% of work

### Parallel Opportunities
- Phase 1 (scaffolding) can run while planning Phase 2–3
- Within Phase 4: DatabaseSelectorViewModel and SettingsViewModel can be developed in parallel
- Within Phase 5: SettingsView, TableStatusView, DatabaseSelectorView can be developed in parallel (after ViewModels complete)
- Phases 6 and 7 can be finalized while Phases 4–5 are in progress

---

## Key Technical Decisions

### Database Validation
- Check for presence of core tables: paziente, consulto, esame, trattamento, valutazione, anamnesi_remota, anamnesi_prossima
- Do NOT perform schema validation (allow schema variations)
- Return user-friendly error if any core table is missing

### Configuration Format
- Use json for simplicity and native Swift Codable support
- Store in `~/Library/Application Support/WOA/configuration/app-settings.json`
- Include fields: database path, last validated date, logging level, theme

### Async/Await
- Use Task blocks in ViewModels to perform long-running operations (import, validation)
- Avoid blocking main thread
- Show loading indicators during async operations

### Error Handling
- Never use `try!` or `fatalError()`
- Always use `do/catch` blocks
- Log all errors with AppLogger
- Provide user-friendly error messages in UI
- Include error context for debugging

### Logging
- Use OSLog with subsystem "com.woa.application"
- Log to both console and file
- Default level: INFO
- Style: `✅ Database connected: /path/to/db` and `❌ SQL error: no such table`

### Sandbox Compliance
- Never use hardcoded paths like `~/Documents` or `/Users/username`
- Always use `FileManager.urls(for:in:)` APIs
- Use Security-Scoped Bookmarks only for user-selected files (not for app's own database)
- Test with sandbox enabled in Xcode

---

## Acceptance Criteria

### Build & Compilation
- [ ] `xcodebuild build -scheme WOA` completes without errors
- [ ] No compiler warnings related to deprecated APIs
- [ ] All Swift files follow consistent style (no syntax errors)

### Sandbox Compliance
- [ ] App runs without sandbox denials in system console
- [ ] File operations respect App Sandbox restrictions
- [ ] Can read/write to AppSupport directory
- [ ] Cannot access user's home directory outside sandbox

### First-Run Database Selection Flow
- [ ] Launch app → SettingsView displayed with "Database Configuration Required"
- [ ] Click "Browse Database File" → NSOpenPanel opens filtered to .db files
- Select a valid SQLite file (e.g., `data/woa-demo.db`) → file path shown
- [ ] Click "Import Database" → validation starts (progress shown)
- [ ] After successful validation → file copied to `~/Library/Application Support/WOA/database/woa.db` (not `application.db`)
- [ ] TableStatusView displayed showing all 8+ tables with record counts
- [ ] Click "Continue" → stored configuration allows immediate skip of setup on next launch

### Settings Persistence
- [ ] Close app and relaunch → SettingsView shows "Connected ✅" without re-selecting
- [ ] Table list displays with accurate record counts
- [ ] Configuration file exists at expected path with correct content
- [ ] Timestamps updated correctly

### Error Handling & Recovery
- [ ] Select invalid file → error message displayed (not crash)
- [ ] Select empty SQLite file → validation fails with "Database schema not recognized" message
- [ ] Try to import corrupted database → error caught and logged
- [ ] Network timeout during import → graceful error handling (if applicable)
- [ ] All errors logged to both console and `~/Library/Application Support/WOA/logs/app.log`

### Logging Verification
- [ ] Console shows `✅ Database connected: /path/to/woa.db` on successful import
- [ ] Console shows `❌ SQL error: no such table: paziente` if schema is invalid
- [ ] Log file exists at `~/Library/Application Support/WOA/logs/app.log`
- [ ] Log file includes timestamps, log level, and readable messages
- [ ] Old log files rotated (keep last 5 files, ~10MB each)

### Table Counting Accuracy
- [ ] Query returns all tables present in database
- [ ] Record counts match actual data (verify with SQLite CLI)
- [ ] Tables sorted alphabetically in display
- [ ] Format matches spec: `- paziente (100)`, `- consulto (332)`

### Code Quality
- [ ] No `try!`, `fatalError()`, or assertion failures in production code
- [ ] All functions have descriptive comments
- [ ] MVVM separation strictly enforced (no View accessing SQLite, no ViewModel accessing SwiftUI)
- [ ] Consistent naming conventions (camelCase for variables, PascalCase for types)
- [ ] No hardcoded paths or magic strings

### Documentation
- [ ] README.md includes step-by-step Xcode setup with screenshots
- [ ] Sandbox entitlements explained with reasoning
- [ ] Build script works and produces Release binary
- [ ] All source files include file-header comments with purpose and functionality
- [ ] Complex code sections include inline comments for clarity

---

## File Checklist

### Core Infrastructure (Phase 1)
- [ ] `src/WOA/Utils/AppPaths.swift`
- [ ] `src/WOA/Utils/AppLogger.swift`
- [ ] `src/WOA/Utils/DatabaseURLProvider.swift`
- [ ] `src/WOA/Utils/DatabaseValidator.swift`
- [ ] `src/WOA/Utils/DatabaseMigrator.swift`
- [ ] `src/WOA/Utils/DatabaseInstaller.swift`
- [ ] `src/WOA/Utils/SQLiteConnection.swift`

### Data Models (Phase 2)
- [ ] `src/WOA/Models/DatabaseConnection.swift`
- [ ] `src/WOA/Models/AppSettings.swift`
- [ ] `src/WOA/Models/TableInfo.swift`
- [ ] `src/WOA/Services/ConfigurationService.swift`

### Database Queries (Phase 3)
- [ ] `src/WOA/Repositories/TableRepository.swift`

### ViewModels (Phase 4)
- [ ] `src/WOA/ViewModels/SettingsViewModel.swift`
- [ ] `src/WOA/ViewModels/DatabaseSelectorViewModel.swift`

### Views (Phase 5)
- [ ] `src/WOA/Views/SettingsView.swift`
- [ ] `src/WOA/Views/TableStatusView.swift`
- [ ] `src/WOA/Views/DatabaseSelectorView.swift`

### App Entry (Phase 6)
- [ ] `src/WOA/WOA.swift`
- [ ] `src/WOA/Resources/Info.plist`
- [ ] `src/WOA/Resources/WOA.entitlements`
- [ ] `src/WOA.xcodeproj/project.pbxproj`

### Documentation (Phase 7)
- [ ] `README.md`
- [ ] `build-release.sh`

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Sandbox denials during file copy | Medium | High | Test on clean system, validate permissions before operation |
| SQLite connection pooling issues | Low | Medium | Use single connection per app session, close properly on teardown |
| Large database import hanging UI | Medium | High | Perform import in background Task, show progress |
| Invalid schema not caught by validator | Medium | Medium | Check for core tables explicitly, log table details |
| Logging file disk space grows unbounded | Low | Low | Implement log rotation (5 files, 10MB each) |
| Xcode project generation tool issues | Low | High | Manually verify .pbxproj structure, use known-good template |

---

## References

- [copilot-instructions.md](../../copilot-instructions.md) — Architecture rules, sandbox guidelines
- [swiftui.instructions.md](../../instructions/swiftui.instructions.md) — SwiftUI & MVVM patterns
- [storage.instructions.md](../../instructions/storage.instructions.md) — Sandbox storage rules
- [data/woa-schema.sql](../../../data/woa-schema.sql) — Database schema for validation
- [01_woa-db-selector.prompt.md](../01_woa-db-selector.prompt.md) — Feature requirements

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-08-17 | GitHub Copilot | Initial plan for database selector & settings UI feature |

