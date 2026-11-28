### Executive Summary

Reviewed first-party Swift, SQLite persistence, SwiftUI state/lifecycle paths, tests, storage, release scripts, CI configuration, and applicable repository guidance. **3 confirmed bugs, 2 probable bugs, and 1 conditional risk** were found; all are Medium severity except the Low conditional risk. The highest-priority concerns are incomplete database copies when a source has uncheckpointed WAL data, patient data written to logs, and retained detail ViewModels. No confirmed Critical or High defect was found. macOS build and test validation were unavailable.

### Validation Performed

- Searched Swift code for error handling, SQLite transactions, security-scoped access, task ownership, logging, and persistence patterns; traced relevant callers and tests.
- Inspected repository instructions, architecture/database documentation, relevant plans, project membership, and release configuration.
- `get_errors` reported no editor diagnostics. The migration resource is included in the Xcode target; the duplicate-looking exam ViewModel file is not.
- `git status --short --branch` showed three untracked agent-definition files; they were left untouched.
- No build or test command was run. This is a Windows environment, the app build requires Xcode/macOS, and the Swift toolchain probe was skipped.

### Confirmed Bugs

[BUG-001] Detail ViewModel event Tasks retain their owners

Classification: CONFIRMED BUG  
Severity: Medium  
Confidence: High  
Category: Lifecycle  
Location: `PazienteDetailViewModel.swift:39`, `ConsultoDetailViewModel.swift:39`, `ConsultoDetailEditViewModel.swift:57`  
Evidence: Each ViewModel stores a Task whose open-ended stream loop accesses the ViewModel and calls `load()`. The ViewModel also intends to cancel that Task from `deinit`; the stored Task’s closure retains the ViewModel, so that cleanup cannot be reached.  
Trigger: Open and leave one of these detail destinations; repeat navigation.  
Observed/Expected: The ViewModel and event subscription remain alive after the destination is dismissed; they should be released and stop receiving events.  
Impact: Retained ViewModels and stale database reloads accumulate during navigation.  
Root cause: A long-lived Task stored by its owner strongly captures that owner.  
Recommendation: Break the ownership cycle or manage subscription lifetime from the view/task lifecycle.  
Validation: Add a lifecycle test that dismisses the destination, verifies the ViewModel deallocates, and confirms its subscription is removed.

[BUG-002] Patient identifiers are written to logs

Classification: CONFIRMED BUG  
Severity: Medium  
Confidence: High  
Category: Security  
Location: `PatientRepository.swift:255`, `PazienteSearchViewModel.swift:42`, `AppLogger.swift:21`  
Evidence: Patient creation logs the patient’s name; search logs the raw query. The logger marks unified-log messages public and also writes the message to a plaintext file at `AppLogger.swift:42`.  
Trigger: Create a patient or search by a patient-identifying string.  
Observed/Expected: Patient information appears in diagnostic logs; logs should not contain patient names or search terms.  
Impact: Patient-identifying information can be exposed through collected logs or shared diagnostics.  
Root cause: Sensitive values are interpolated into general-purpose logging calls.  
Recommendation: Remove or redact patient data from log messages.  
Validation: Use a sentinel patient name/query and verify it is absent from both logging outputs.

[BUG-003] A configured release workflow invokes a missing script

Classification: CONFIRMED BUG  
Severity: Medium  
Confidence: High  
Category: Other  
Location: `codemagic.yaml:62`  
Evidence: The tag-triggered `woa-release-build` workflow runs `chmod +x build_release.sh` and `./build_release.sh`; no root-level `build_release.sh` exists. The repository’s release script is under `scripts` and has a different interface.  
Trigger: A matching `v*` tag starts `woa-release-build`.  
Observed/Expected: The workflow fails at its release-script step instead of producing its artifacts.  
Impact: This configured release workflow cannot complete.  
Root cause: CI references a removed or renamed script.  
Recommendation: Point the workflow at the supported release process or remove the stale workflow.  
Validation: Add a configuration check that verifies every referenced workflow script exists and its invocation matches the script’s interface.

### Probable Bugs

[BUG-004] Copy mode can omit committed SQLite WAL data

Classification: PROBABLE BUG  
Severity: Medium  
Confidence: High  
Category: Persistence  
Location: `DatabaseInstaller.swift:21`, `DatabaseMigrator.swift:9`  
Evidence: Installation copies only the selected database file. The destination migrator then removes destination WAL/SHM sidecars and runs normalization. SQLite can store committed, uncheckpointed transactions in the source `-wal` file, which is not copied.  
Trigger: Copy a database in WAL mode while it has committed but uncheckpointed changes.  
Observed/Expected: The installed copy can omit those changes; it should represent a consistent current snapshot of the source.  
Impact: Recent patient-record changes can be absent from the active copy.  
Root cause: Copying the main database file is not a consistent SQLite backup when WAL data exists.  
Recommendation: Use SQLite’s backup/checkpoint mechanism or otherwise capture a consistent database snapshot before installation.  
Validation: Create a WAL-mode source with an uncheckpointed committed row, install it, and verify that row exists in the destination.

[BUG-005] Synchronous database and file operations block the main actor

Classification: PROBABLE BUG  
Severity: Medium  
Confidence: High  
Category: Concurrency  
Location: `DatabaseManagementViewModel.swift:472`, `PazienteSearchViewModel.swift:37`  
Evidence: These ViewModels are `@MainActor`; their `Task` closures inherit that isolation, then call synchronous database work. Import also calls synchronous file copying and database normalization, including `VACUUM`, at `DatabaseInstaller.swift:21` and `DatabaseMigrator.swift:15`.  
Trigger: Import or query a large database, or access a slow external volume.  
Observed/Expected: The main actor is occupied until the synchronous operation returns, so progress and UI interaction can stall; long work should leave the UI responsive.  
Impact: The app can appear hung during import or database operations.  
Root cause: Wrapping synchronous work in `Task {}` does not move it off the inherited main actor.  
Recommendation: Run blocking database and file operations on an appropriate non-main execution context, then publish results on the main actor.  
Validation: Exercise a deliberately slow import/query while checking that a main-actor UI heartbeat continues.

### Conditional Risks Requiring Validation

[BUG-006] Installer may skip the Gatekeeper helper when run as documented

Classification: CONDITIONAL RISK  
Severity: Low  
Confidence: Medium  
Category: Other  
Location: `install-woa-swift.sh:323`  
Evidence: The installer looks for `./unlock-woa.sh` relative to the current directory, while the helper is at `unlock-woa.sh`. The documented invocation runs the installer from the repository root. The installer warns and continues if the helper is not found.  
Trigger: Run the documented command from the repo root with a downloaded app that has a quarantine attribute.  
Observed/Expected: The unlock step is skipped and the app may be blocked from launching; the helper should be found relative to the installer or the condition clearly handled.  
Impact: Installation may complete but the app may not launch.  
Root cause: The helper path depends on the caller’s working directory.  
Recommendation: Resolve the helper path relative to the installer script.  
Validation: Run the installer’s path-resolution logic from the documented working directory with a quarantined test bundle.

### Suggested Regression Tests

- Verify ViewModels and stream subscriptions are released after leaving patient and consultation detail destinations.
- Assert patient-name and search-query sentinels never appear in app or unified logs.
- Validate the release workflow’s referenced script exists and accepts its configured invocation.
- Verify copied databases include committed WAL-backed changes.
- Keep the main actor responsive during a slow import or database query.

### Final Defect Gate

PASS WITH RISKS: no confirmed release-blocking defect was found, but probable or conditional defects require follow-up. The WAL-copy and patient-data logging issues deserve priority because they affect data integrity and privacy. Build and test results remain unverified in this Windows environment.
