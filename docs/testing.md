# Testing strategy

The test harness is designed to be **fast to run and useful for catching
high-impact regressions as the codebase evolves**. It favors focused tests of
stable behavior at application boundaries over slow, broad UI automation or a
headline code-coverage percentage. Tests use the production SQLite and
database-validation source files directly, without third-party dependencies.

## Run the tests

From the repository root on macOS with Xcode command-line tools installed:

```bash
bash scripts/test.sh
```

SwiftPM builds only the production files needed by this focused harness and
runs the XCTest suite in a dedicated temporary scratch directory. This keeps
tests independent from Xcode/SourceKit background indexing builds, which can
otherwise contend for the repository's default SwiftPM build lock. The scratch
directory is reused so subsequent test runs avoid rebuilding. Filter to a
single suite while iterating:

```bash
bash scripts/test.sh --filter DatabaseValidatorTests
bash scripts/test.sh --filter SQLiteConnectionTests
bash scripts/test.sh --filter PatientRepositoryLifecycleTests
```

`--filter` accepts a regular expression and runs only matching suites or test
cases. To temporarily skip one suite or matching test cases, use `--skip`:

```bash
bash scripts/test.sh --skip PatientRepositoryLifecycleTests
bash scripts/test.sh --skip 'DatabaseValidatorTests|SQLiteConnectionTests'
```

The wrapper forwards SwiftPM test options, so options such as `--jobs 1` can
also be passed through. Skipping tests is useful for focused local iteration,
but run the full suite before handing off changes.

## Database isolation

Every test uses its own database state; tests never connect to the installed
application database or write into Application Support:

- `DatabaseValidatorTests` creates SQLite files in unique subdirectories of
  `FileManager.default.temporaryDirectory`. The missing-file case verifies
  validation does not create its database file, and the invalid-file case
  writes only a disposable text file there.
- `SQLiteConnectionTests` creates a uniquely named temporary SQLite database
  for each test and removes it afterward.
- `PatientRepositoryLifecycleTests` copies the checked-in
  [`data/woa-empty.db`](../data/woa-empty.db) fixture into a unique temporary
  directory, adds the audit table needed by repository writes to that copy,
  and runs the production repository CRUD calls against the copy. The fixture
  itself is never opened for writing. The temporary directory is removed by
  the test teardown, including when an assertion fails.

Tests that need mutable database state should follow the same pattern: use an
in-memory or temporary database, seed only the schema/data relevant to the
test, and clean it up. Never use a user's database as a test fixture.

## Current coverage

| Area | Regression behavior covered |
| --- | --- |
| Database onboarding validation | Accepts a database with every required WOA table; reports all missing core tables in stable order; rejects missing and non-SQLite files without creating a database. |
| SQLite connection | Executes multi-statement scripts; binds text as data rather than SQL; preserves unrelated tables; surfaces malformed SQL errors. |
| Patient entity graph | Exercises create, read, update, and delete for patients, consultations, remote histories, treatments, evaluations, and exams using the production repository and a temporary copy of the empty database. |

These are focused unit/integration checks of persistence and database
selection foundations. They do **not** claim complete application coverage:
SwiftUI presentation, navigation, ViewModels, migration orchestration, and
release scripts are not currently exercised by automated tests.

## Guidelines for adding tests

When implementing a feature or fixing a regression:

1. Add a fast test for the user-visible or data-integrity behavior that could
   regress, not just for implementation details.
2. Keep tests at the layer that owns the behavior. Test validation and state
   transitions without UI; test repository and SQLite behavior with temporary
   or in-memory databases.
3. Use `FileManager.default.temporaryDirectory` for test files, isolate
   `UserDefaults` with a dedicated suite when needed, and clean up resources
   after each test. Never read or write the user's application database or
   application data directories.
4. For ViewModels, inject mocked services and avoid SQL or filesystem access.
   For services, prefer mocked repositories unless the database boundary itself
   is what the test needs to verify.
5. Keep each test deterministic, independent, and quick. Avoid sleeps, network
   access, machine-specific paths, and unnecessary UI launch/automation.
6. Assert important failure behavior as well as success behavior. Keep error
   expectations specific enough to catch meaningful changes.
7. Run `bash scripts/test.sh` before handing off changes. Add a focused regression test
   alongside each bug fix, and update this coverage table when the harness
   gains a new area.

The package target intentionally compiles a small selection of production
files instead of the full SwiftUI application. If a feature needs tests that
cannot be exercised through this harness, extend the harness deliberately or
add an appropriate Xcode test target; document any additional command and
coverage here.
