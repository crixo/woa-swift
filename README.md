# WOA

WOA is a macOS SwiftUI application for working with patient records stored in a
SQLite database. The app runs in the macOS App Sandbox and requires the user to
select a compatible database before database-backed features are available.

## Requirements

- macOS 14.6 or later
- Xcode with a macOS SDK that supports the project's 14.6 deployment target

## Get started

Open [`src/WOA.xcodeproj`](src/WOA.xcodeproj) in Xcode, select the **WOA**
scheme, set a development team under **Signing & Capabilities**, then build and
run. On first launch, follow the database setup flow described in
[Database selection and sandbox access](docs/database-lifecycle.md).

## Documentation

The README is the project overview and documentation index. Operational and
implementation details live in the guides below.

- [Database selection, storage, and App Sandbox permissions](docs/database-lifecycle.md)
- [Database migrations and audit history](docs/migrations.md)
- [Application architecture, navigation, forms, and change notifications](docs/architecture.md)
- [Testing strategy, current coverage, and test guidelines](docs/testing.md)
- [Local builds, release publishing, CI, and installation](docs/build-and-release.md)
- [Working with GitHub Copilot and repository guidance](docs/github-copilot.md)
- [SQLite schema reference](data/woa-schema.sql)

## Project layout

- [`src/WOA/`](src/WOA/) — SwiftUI app, presentation, application logic, and SQLite access.
- [`data/`](data/) — reference schema, empty database, and bundled SQL migrations.
- [`scripts/`](scripts/) — build/release, install, and Gatekeeper helper scripts.
- [`docs/`](docs/) — detailed product and developer documentation.

WOA uses a layered design: views, view models, services, repositories, and
storage utilities. See the [architecture guide](docs/architecture.md) before
changing application flows or shared UI components.
