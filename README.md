# WOA

WOA is a macOS SwiftUI application for browsing and managing patient records
stored in SQLite. It is intended for desktop users who work with the WOA
database schema; it is not a cloud service or a clinical decision system.

## Requirements

- macOS 14.6 or later.
- Xcode and macOS SDK support for the project's macOS 14.6 deployment target.
- For release operations: Git, GitHub CLI (`gh`), Xcode command-line tools,
  and Sparkle's `generate_appcast` utility.

## Functionality

### Functional

- Search and browse patient records.
- View and edit patient details, consultations, remote histories, treatments,
  evaluations, and exams.
- Track recent patient changes and database migration history.
- Configure application preferences and database access.
- Optional Google sign-in is implemented through AppAuth. Gmail sending exists
  as a service but is not exposed as an in-app email workflow.

### Non-functional

- Native macOS SwiftUI application with a single-window navigation flow.
- SQLite persistence, bundled schema migrations, and transaction-based entity
  audit records.
- App Sandbox with user-selected access to external databases; app-owned data
  is stored under Application Support.
- OSLog-based application logging.
- Sparkle update checks and signed update archives.
- Focused XCTest coverage for database validation, SQLite access, and patient
  repository lifecycle behavior.

## Set up the development environment

Clone the repository and open its shared Xcode project:

```bash
git clone https://github.com/crixo/woa-swift.git
cd woa-swift
open src/WOA.xcodeproj
```

The project references the ignored local file `src/Config/Secrets.xcconfig`,
which is not included in the repository. Create it locally if Xcode reports
that the project configuration is missing. To use the Google iOS OAuth client,
set `GOOGLE_IOS_CLIENT_ID` in that file to the client whose reversed scheme
matches `src/WOA/Resources/Info.plist`. Do not commit the local config. See
[Google authentication](docs/GOOGLE_AUTH_SETUP.md).

Select the **WOA** scheme. Set a development team under **Signing &
Capabilities** if you need a signed local build.


## Run the application

In Xcode choose **Product → Run**, or open the built app:

```bash
open build/DerivedData/Build/Products/Debug/WOA.app
```

WOA needs a compatible SQLite database before database-backed screens are
available. See [Database selection and sandbox access](docs/database-lifecycle.md). A database empty sample that can be used for initial setup is provided in the repository at `./data/woa-empty.db`

## Run tests

Run the focused XCTest harness from the repository root:

```bash
bash scripts/test.sh
```

The harness uses SwiftPM and temporary databases. Filters and coverage details
are in the [testing guide](docs/testing.md).

### Publish a release

```bash
bash scripts/release/full-release-orchestration.sh \
  --scheme WOA \
  --project src/WOA.xcodeproj \
  --app-name WOA \
  --dry-run
```

After reviewing the rehearsal and validating the artifacts, repeat the
orchestration command without `--dry-run`.

 It creates a signed `.app`,
`.app.zip`, and `.dmg`, commits and tags the version/appcast, creates the GitHub
Release, and pushes the appcast commit to `main`. For the full procedure and
recovery steps, see [Build, release, and installation](docs/build-and-release.md).

## Install from GitHub Releases

Download a `.dmg` from
[GitHub Releases](https://github.com/crixo/woa-swift/releases), open it, and
drag `WOA.app` to Applications.

Alternatively, on macOS run the repository installer with a release tag:

```bash
bash scripts/install/install-woa-swift.sh v0.5.0
```

The installer selects a ZIP asset, requires `sudo`, requires WOA to be quit,
validates the staged bundle, and launches the installed app. It removes the
quarantine attribute using the checked-in helper. Only install a release you
trust. See [Build, release, and installation](docs/build-and-release.md).

## Check for updates

Sparkle checks the configured appcast on its schedule (24 hours) and provides
**Check for Updates…** in the application menu. See the [Sparkle guide](docs/sparkle.md).

## Troubleshooting

- **Build fails opening the project configuration:** check for the ignored
  `src/Config/Secrets.xcconfig` reference and create the local file if absent.
- **Database-backed screens are unavailable:** select a compatible database;
  review [database selection and recovery](docs/database-lifecycle.md).
- **Tests cannot run:** tests require macOS, Xcode command-line tools, and
  SwiftPM. The repository test wrapper is `bash scripts/test.sh`.
- **Release preflight fails:** check the clean `main` branch, remote sync, `gh
  auth status`, the signing identity, and Sparkle tools as described in
  [Build, release, and installation](docs/build-and-release.md).
- **An update is not offered:** use **Check for Updates…**, confirm the
  appcast feed and release ZIP are public, and see the
  [Sparkle troubleshooting guide](docs/sparkle.md).

## Repository layout

- `src/WOA/` — SwiftUI application, view models, services, repositories,
  utilities, and resources.
- `src/WOA.xcodeproj/` — Xcode project and shared scheme.
- `data/` — reference SQLite schema, empty fixture, and migration SQL.
- `scripts/` — test, install, signing, and release tools.
- `docs/` — product and developer guides.
- `tests/` — focused XCTest suite.

## Documentation

| Document | Description |
|---|---|
| [Architecture](docs/architecture.md) | Layers, navigation, shared forms, change events, and auditing |
| [Build, release, and installation](docs/build-and-release.md) | Local builds, test commands, release workflow, validation, installation, and troubleshooting |
| [CI/CD](docs/ci-cd.md) | Codemagic triggers, actual workflow steps, and known workflow gaps |
| [Database lifecycle](docs/database-lifecycle.md) | Database selection, sandbox permissions, storage, and recovery |
| [Migrations](docs/migrations.md) | Migration authoring, runtime ledger, and audit history |
| [Testing](docs/testing.md) | Test harness, isolation, coverage, and test guidance |
| [Google authentication](docs/GOOGLE_AUTH_SETUP.md) | Current OAuth configuration and implementation limitations |
| [Code-signing certificate](docs/SIGNING-CERTIFICATE.md) | Creating, using, verifying, and backing up the local signing identity |
| [Sparkle](docs/sparkle.md) | Update configuration, appcast publishing, and checks |
| [Xcode project settings](docs/project-settings.md) | Current plist, entitlements, packages, configuration, and settings behavior |
| [GitHub Copilot guidance](docs/github-copilot.md) | Repository instruction, plan, prompt, and reviewer files |
| [AI-assisted development notes](docs/ai-assisted-journey.md) | Historical development observations, not current behavior specifications |
| [SQLite schema](data/woa-schema.sql) | Reference database schema |
