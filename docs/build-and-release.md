# Build, release, and installation

Commands are run from the repository root. Xcode, the WOA shared scheme, and a
macOS 14.6 SDK are required for app builds.

## Configure the development environment

Open `src/WOA.xcodeproj` and select the **WOA** scheme. The project references
`src/Config/Secrets.xcconfig`, which is ignored by Git and absent from the
repository. If Xcode reports that this project configuration is missing,
create the local file; set `GOOGLE_IOS_CLIENT_ID` there when configuring the
Google iOS client. Do not put credentials in the repository. See
[Google authentication](GOOGLE_AUTH_SETUP.md).

Set a development team under **Signing & Capabilities** for a local app build.
The release scripts use the separate self-signed `CrixoDev` identity by
default; see [Code-signing certificate](SIGNING-CERTIFICATE.md).

## Build and run locally

Debug build (configure a development team in Xcode first):

```bash
xcodebuild \
  -project src/WOA.xcodeproj \
  -scheme WOA \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  build
```

Run from Xcode with **Product → Run**, or open the built app:

```bash
open build/DerivedData/Build/Products/Debug/WOA.app
```

WOA requires a selected compatible database before database-backed screens are
available. The implementation currently replaces its loaded settings store
with a new default store during initialization, so saved database settings are
not reliably restored at launch. This startup issue is detailed in
[Database lifecycle](database-lifecycle.md) and [Project settings](project-settings.md).

## Run tests

The repository's focused SwiftPM/XCTest harness runs without launching the
app:

```bash
bash scripts/test.sh
bash scripts/test.sh --filter SQLiteConnectionTests
```

See [Testing](testing.md) for filters, coverage, and isolation requirements.

## Create, validate, and publish a release

### Prerequisites

The release orchestrator checks for a clean, synchronized `main` branch,
GitHub CLI authentication and repository write permission, the shared Xcode
scheme, and (unless signing is disabled) the configured Keychain certificate.
It also needs Xcode command-line tools, `hdiutil`, `ditto`, and Sparkle's
`generate_appcast` utility, plus the Sparkle EdDSA private key in the Keychain
or supplied with `--ed-key-file`.

The default release identity is `CrixoDev`. The orchestrator creates the app,
ZIP, and DMG in `dist/`; its package step removes and recreates that directory.
Preserve any important existing contents before running it.

### Rehearse

```bash
bash scripts/release/full-release-orchestration.sh \
  --scheme WOA \
  --project src/WOA.xcodeproj \
  --app-name WOA \
  --dry-run
```

Preflight fetches from the remote and may fast-forward local `main` before the
dry run begins. The dry run then performs versioning, archive, packaging,
Sparkle signing, local commit/tag creation, and simulated publish checks. It
rolls back the release changes, but does not undo a preflight fast-forward. It
still creates build artifacts and does not publish. Inspect output and the
generated artifacts before proceeding.

### Validate the final app and artifacts

Check the app bundle produced in `dist/`:

```bash
codesign --verify --deep --strict --verbose=2 dist/WOA.app
codesign -d --verbose=2 dist/WOA.app
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/WOA.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' dist/WOA.app/Contents/Info.plist
```

Repeat signature verification on the app extracted from the final ZIP or DMG
before distribution. `sparkle-sign.sh` checks app configuration, ZIP version,
EdDSA signature, enclosure URL, and appcast structure; XML well-formedness is
checked when `xmllint` is available. The release publisher checks the GitHub
asset and tag before pushing the appcast.

The scripts create a self-signed signature, not a Developer ID signature; they
do not notarize the app. A Gatekeeper warning can therefore occur. See
[Code-signing certificate](SIGNING-CERTIFICATE.md).

### Publish

After reviewing the rehearsal, run the same command without `--dry-run`:

```bash
bash scripts/release/full-release-orchestration.sh \
  --scheme WOA \
  --project src/WOA.xcodeproj \
  --app-name WOA
```

This changes local and remote GitHub state. The sequence is: preflight; version
bump; Xcode archive; `.app`, `.app.zip`, and `.dmg` packaging and code signing;
Sparkle signature and appcast update; local commit and annotated tag; GitHub
Release creation; then push the tagged commit to `main` so the appcast goes
live. The `--new-major` option selects a major version bump. Never run a real
release merely to validate the documentation. By default, the next minor
version is calculated from the latest Git tag; use `--new-major` for a major
bump or `--new-patch` to increment only the patch component. The selected
version is written to the project settings and then carried through the same
build, packaging, tagging, and publishing steps.

If publication stops after the tag is pushed, resume only the failed step:

```bash
bash scripts/release/publish-github-release.sh --version 1.2.3
bash scripts/release/publish-appcast.sh --version 1.2.3
```

Replace the example version with the actual release version. See
[CI/CD](ci-cd.md) for Codemagic's separate workflows and known configuration
gaps.

## Install from GitHub Releases

For manual installation, download a `.dmg` from
[GitHub Releases](https://github.com/crixo/woa-swift/releases), open it, and
drag `WOA.app` to Applications.

The repository installer selects a ZIP asset for a specific tag and installs
the app into `/Applications`:

```bash
bash scripts/install/install-woa-swift.sh v0.5.0
```

It uses `sudo`, requires the current app to be quit, stages and validates the
new bundle, rolls back activation failures, removes quarantine using the
adjacent helper, and launches the app. Only install releases you trust.

## Updates

Sparkle performs scheduled update checks and offers **Check for Updates…** in
the app menu. Updates use the public `appcast.xml` feed and signed `.app.zip`
assets. See [Sparkle](sparkle.md).

## Troubleshooting

- **Xcode cannot read a configuration file:** confirm the local ignored
  `src/Config/Secrets.xcconfig` exists; see [Project settings](project-settings.md).
- **Release preflight rejects the worktree:** commit or stash changes, switch
  to `main`, and synchronize it with the configured remote.
- **Signing identity not found:** create/import the certificate and check
  `security find-identity -p codesigning`; see
  [Code-signing certificate](SIGNING-CERTIFICATE.md).
- **Sparkle tool not found:** build once to fetch Swift packages, set
  `SPARKLE_BIN`, or pass `--sparkle-bin` to the orchestrator.
- **Release stops after tag push:** do not delete the published tag; rerun the
  indicated publisher step with the same version.
- **Database not restored on relaunch:** this is a current app initialization
  defect, not a release or database-selection step; see
  [Database lifecycle](database-lifecycle.md).
