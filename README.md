# WOA

WOA is a macOS SwiftUI application for working with patient records stored in a
SQLite database. The app runs in the macOS App Sandbox and requires the user to
select a compatible database before database-backed features are available.

## Requirements

- macOS 14.6 or later
- Xcode with a macOS SDK that supports the project's 14.6 deployment target

## Main functionalities

### Functional features

- **Patient search and directory** — Query and browse patient records
- **Patient details** — View and edit patient demographics and history
- **Consultations** — Track consultation records linked to patients
- **Exams** — Manage examination records and results
- **Treatments** — Record and track treatment procedures
- **Evaluations** — Document clinical evaluations
- **Remote history** — Access and manage remote patient history records
- **Application settings** — Configure preferences and display options
- **Google Authentication** — Gmail-integrated login and credentials management

### Non-functional characteristics

- **Platform** — macOS 14.6 and later; native SwiftUI app with single-window navigation
- **Data storage** — SQLite database with schema versioning via bundled migrations
- **Sandbox** — App Sandbox enabled for security; user-controlled database access via security-scoped bookmarks
- **Updates** — Sparkle auto-update framework with Ed25519 signature verification
- **Logging** — Structured logging with OSLog
- **Code signing** — Self-signed certificate for consistent designated requirements across updates
- **Testing** — XCTest suite with focused regression tests and database isolation

## Get started

### Quick start

Open [`src/WOA.xcodeproj`](src/WOA.xcodeproj) in Xcode, select the **WOA**
scheme, set a development team under **Signing & Capabilities**, then build and
run. On first launch, follow the database setup flow described in
[Database selection and sandbox access](docs/database-lifecycle.md).

### How-to procedures

- **[Set up the development environment](#set-up-the-development-environment)** — Install dependencies and prepare for local development
- **[Build the application](#build-the-application)** — Build locally in Xcode or from the command line
- **[Run the application](#run-the-application)** — Launch WOA locally
- **[Run tests](#run-tests)** — Execute the test suite
- **[Create a release](#create-a-release)** — Build, sign, and publish a new version
- **[Install from GitHub Releases](#install-from-github-releases)** — Install a released build
- **[Configure Google authentication](#configure-google-authentication)** — Set up Gmail credentials
- **[Troubleshoot Sparkle updates](#troubleshoot-sparkle-updates)** — Debug auto-update issues

## Set up the development environment

### Prerequisites

- macOS 14.6 or later
- Xcode 15 or later with macOS SDK support
- Xcode command-line tools
- Git

### Install dependencies

No external package manager installation is required. Swift Package Manager is configured in `Package.swift` and resolves dependencies automatically in Xcode.

### Clone and open the project

```bash
git clone https://github.com/crixo/woa-swift.git
cd woa-swift
open src/WOA.xcodeproj
```

### Configure signing

1. In Xcode, select the **WOA** target.
2. Go to **Signing & Capabilities**.
3. Under **Signing**, choose your development team from the dropdown.
4. The provisioning profile is automatically managed by Xcode.

## Build the application

### Build in Xcode

1. Open `src/WOA.xcodeproj` in Xcode.
2. Select the **WOA** scheme (top-left dropdown).
3. Product → Build, or press Command+B.

Build output appears in the Xcode build log.

### Build from the command line

```bash
xcodebuild -scheme WOA -configuration Release
```

The built app appears in `build/Release/WOA.app`.

## Run the application

### From Xcode

1. Select the **WOA** scheme.
2. Product → Run, or press Command+R.

### From the command line

```bash
open build/Release/WOA.app
```

### On first launch

WOA requires a SQLite database before features become available. The database setup flow is described in [Database selection, storage, and App Sandbox access](docs/database-lifecycle.md).

## Run tests

```bash
bash scripts/test.sh
```

For detailed information, including filtering tests and coverage areas, see [Testing strategy](docs/testing.md).

## Create a release

```bash
bash scripts/release/full-release-orchestration.sh
```

The full workflow:

1. Preflight validation (git status, network connectivity)
2. Version bump in `project.pbxproj`
3. Build and sign the app
4. Create a DMG package
5. Update the Sparkle appcast
6. Create a git commit and tag
7. Create the GitHub Release with artifacts
8. Publish the appcast feed

For step-by-step details and individual script usage, see [Build, release, and installation](docs/build-and-release.md).

## Install from GitHub Releases

1. Navigate to [github.com/crixo/woa-swift/releases](https://github.com/crixo/woa-swift/releases).
2. Download the latest `WOA.dmg` or `.pkg`.
3. For DMG: mount the image and drag WOA to Applications.
4. For PKG: double-click to run the installer.
5. Launch WOA from Applications.

WOA checks for updates automatically and notifies you when a new version is available.

## Configure Google authentication

Google authentication is optional. To enable it:

1. Create a Google Cloud Console project.
2. Configure OAuth consent and credentials.
3. Add your client ID to the app.

For detailed setup, see [Google authentication setup](docs/GOOGLE_AUTH_SETUP.md).

## Troubleshoot Sparkle updates

For issues with auto-update checking or installation, see [Sparkle auto-update framework](docs/sparkle.md).

## Documentation

The README is the project overview and documentation index. Operational and
implementation details live in the guides below.

### Core documentation

- [Build, release, and installation](docs/build-and-release.md) — Local builds, running tests, releases, Sparkle setup, signing, and installation
- [CI/CD — Continuous integration and deployment](docs/ci-cd.md) — Codemagic workflows, release triggers, build configuration
- [Application architecture, navigation, forms, and change notifications](docs/architecture.md) — Layered design, main navigation, shared UI components
- [Database selection, storage, and App Sandbox permissions](docs/database-lifecycle.md) — First-run setup, direct vs. copy modes, sandbox access, recovery
- [Database migrations and audit history](docs/migrations.md) — Adding migrations, runtime process, schema versioning
- [Testing strategy, current coverage, and test guidelines](docs/testing.md) — Running tests, database isolation, test organization

### Additional references

- [Xcode project and target settings](docs/project-settings.md) — Info.plist, build settings, signing, entitlements
- [Code-signing certificate](docs/SIGNING-CERTIFICATE.md) — Creating and managing self-signed certificates
- [Sparkle auto-update framework](docs/sparkle.md) — Key generation, signing configuration, update feed
- [Google authentication setup](docs/GOOGLE_AUTH_SETUP.md) — Gmail credentials and authentication configuration
- [Working with GitHub Copilot and repository guidance](docs/github-copilot.md) — Guidance files, plans, instructions, compliance review
- [SQLite schema reference](data/woa-schema.sql)

## Project layout

- [`src/WOA/`](src/WOA/) — SwiftUI app, presentation, application logic, and SQLite access.
- [`data/`](data/) — reference schema, empty database, and bundled SQL migrations.
- [`scripts/`](scripts/) — build/release, install, and Gatekeeper helper scripts.
- [`docs/`](docs/) — detailed product and developer documentation.

WOA uses a layered design: views, view models, services, repositories, and
storage utilities. See the [architecture guide](docs/architecture.md) before
changing application flows or shared UI components.
