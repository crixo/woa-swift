# Build, release, and installation

This guide covers local builds, running tests, creating releases, and installing updates.

## Build the application locally

### Prerequisites

- macOS 14.6 or later
- Xcode 15 or later with macOS SDK support
- Xcode command-line tools

### Build in Xcode

1. Open `src/WOA.xcodeproj` in Xcode.
2. Select the **WOA** scheme (top-left dropdown).
3. Set a development team under **Signing & Capabilities** in the target.
4. Product → Build, or press Command+B.

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

WOA requires a SQLite database before features become available. The database setup flow is described in [Database selection, storage, and App Sandbox permissions](database-lifecycle.md).

## Run tests

From the repository root on macOS with Xcode command-line tools installed:

```bash
bash scripts/test.sh
```

SwiftPM builds only the production files needed by the test harness and runs the XCTest suite in a dedicated temporary scratch directory. This keeps tests independent from background indexing and avoids contention for the build lock.

Filter to a single suite while iterating:

```bash
bash scripts/test.sh --filter DatabaseValidatorTests
bash scripts/test.sh --filter SQLiteConnectionTests
bash scripts/test.sh --filter PatientRepositoryLifecycleTests
```

Use `--skip` to temporarily skip tests:

```bash
bash scripts/test.sh --skip PatientRepositoryLifecycleTests
```

For detailed information on test organization and coverage, see [Testing strategy](testing.md).

## Create a release

The release process is split into one script per step. Every script can be run on its own, and `full-release-orchestration.sh` runs them all in the right order.

All scripts live in `scripts/release/`. Relative paths passed to them are relative to the repository root.

### Prerequisites

Before starting a release, ensure:

- **Tools:** `git`, `gh` (authenticated with GitHub CLI), `xcodebuild`, `hdiutil`, `ditto`, `sed`, `grep`, `awk`, `find`, and Sparkle's `generate_appcast`
- **Project setup:**
  - `Info.plist` uses `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)` from `project.pbxproj`
  - `Info.plist` contains `SUPublicEDKey` (from Sparkle's `generate_keys`) and `SUFeedURL`
  - `SUFeedURL` should be `https://raw.githubusercontent.com/<owner>/<repo>/main/appcast.xml`
  - Sparkle is embedded in the app (`Sparkle.framework`)
  - GitHub repository is public (required for Sparkle downloads)
- **Git status:**
  - You are on the `main` branch
  - Working tree is clean
  - Local `main` is up-to-date with remote
  - `gh` is authenticated with WRITE/MAINTAIN/ADMIN permission
  - The tag `vX.Y.Z` of the next version does not exist
  - The Xcode scheme is shared (committed to git)

**Version numbering:** The next version is derived from the latest `vX.Y.Z` tag. By default, the minor version increments (`1.4.3 → 1.5.0`). Use `--new-major` for a major bump (`1.4.3 → 2.0.0`). With no tag at all, versioning starts from `v0.0.0`.

### Script responsibilities

| Script | Purpose |
|---|---|
| `release-common.sh` | Shared helpers; sourced by others, never run directly |
| `preflight-check.sh` | Verifies tools, git status, permissions, and Xcode configuration |
| `version-bump.sh` | Calculates next version and updates `project.pbxproj` |
| `build-in-release.sh` | Produces the Xcode archive |
| `package-artifacts.sh` | Converts archive to `.app`, `.app.zip`, and `.dmg` |
| `sparkle-sign.sh` | Signs zip with Sparkle key and updates `appcast.xml` |
| `commit-and-tag.sh` | Creates one release commit and tags it locally |
| `publish-github-release.sh` | Pushes tag and creates GitHub Release |
| `publish-appcast.sh` | Pushes release commit to `main` to make updates live |
| `full-release-orchestration.sh` | Runs all steps 0–7 in order |

**Script conventions:**

- Logs go to stderr; stdout is for machine-readable output (only `version-bump.sh` prints the version)
- All scripts accept `--help` for available options
- When `--version` is omitted, scripts detect it from the zip in `dist/` or the latest tag
- Compatible with bash 3.2 (macOS default)

### Overview

**Why the order matters:** The release tag must contain `appcast.xml` with the **signature of the final zip**, but the zip is only available after the build. So the zip is built and signed first, then one commit holding the version bump and updated `appcast.xml` is created and tagged. The Release is created from that tag, and only at the very end is the commit pushed to `main`, when installed apps start seeing the update.

This works because the GitHub Release download URL is predictable:
```
https://github.com/<owner>/<repo>/releases/download/vX.Y.Z/<zip file name>
```

So the appcast entry is valid before the Release is published.

### Release steps

| Step | Script | Changes working tree | Changes git | Network |
|---|---|---|---|---|
| 0 | `preflight-check.sh` | No | No | Fetches |
| 1 | `version-bump.sh` | `project.pbxproj` | No | Reads tags |
| 2 | `build-in-release.sh` | `build/` | No | No |
| 3 | `package-artifacts.sh` | `dist/`, `build/` | No | No |
| 4 | `sparkle-sign.sh` | `appcast.xml` | No | No |
| 5 | `commit-and-tag.sh` | No | Local tag | No |
| 6 | `publish-github-release.sh` | No | No | Pushes tag, creates Release |
| 7 | `publish-appcast.sh` | No | No | Pushes commit to `main` |

Until step 6, nothing is published. Between steps 6 and 7, the Release exists but the feed still serves the old appcast, so users never see an update that points to a missing file.

### Quick start

```bash
# Rehearsal: build everything, sign, verify, then undo
bash scripts/release/full-release-orchestration.sh --scheme WOA --project src/WOA.xcodeproj --app-name WOA --dry-run

# Real release
bash scripts/release/full-release-orchestration.sh --scheme WOA --project src/WOA.xcodeproj --app-name WOA

# Major version bump
bash scripts/release/full-release-orchestration.sh --scheme WOA --project src/WOA.xcodeproj --app-name WOA --new-major

# With exported Sparkle key
bash scripts/release/full-release-orchestration.sh --scheme WOA --workspace WOA.xcworkspace --ed-key-file ./sparkle_ed_key
```

Or navigate to the release scripts directory and run them individually:

```bash
cd scripts/release
bash ./full-release-orchestration.sh --scheme WOA --project ../src/WOA.xcodeproj --app-name WOA
```

#### Orchestrator options

| Option | Forwarded to | Meaning |
|---|---|---|
| `--scheme <name>` | Steps 0, 2 | Xcode scheme (**required**) |
| `--project <path>` / `--workspace <path>` | Steps 0, 1, 2 | One of them is **required** |
| `--app-name <name>` | Step 3 | App name without `.app` |
| `--configuration <name>` | Step 2 | Default `Release` |
| `--main-branch <name>` | Steps 0, 4, 5, 7 | Default `main` |
| `--remote <name>` | Steps 0, 1, 6, 7 | Default `origin` |
| `--build-dir <path>` | Steps 2, 3, 4 | Default `build` |
| `--dist-dir <path>` | Steps 3–7 | Default `dist` |
| `--appcast-path <path>` | Steps 4, 5, 7 | Default `appcast.xml` |
| `--version <x.y.z>` | Step 1 | Force a specific version |
| `--new-major` | Step 1 | Bump major instead of minor |
| `--skip-version-bump` | Step 1 | Do not write `project.pbxproj` |
| `--sparkle-bin <dir>` | Steps 0, 4 | Folder containing `generate_appcast` |
| `--ed-key-file <path>` | Step 4 | EdDSA private key file |
| `--feed-url <url>` | Step 4 | Expected `SUFeedURL` |
| `--repository <owner/name>` | Steps 4, 7 | GitHub repository |
| `--dry-run` | Steps 6, 7 | Simulate pushes, roll back all changes |

**Dry run behavior:** Runs steps 0–5 for real (build, package, sign, commit, tag), simulates steps 6–7 (push/release), then rolls back the commit, tag, and `appcast.xml`. Build and packaging artifacts are left for inspection. The Release does not exist yet, so step 7 warns about it.

**Rollback and recovery:**

| Failure point | Action |
|---|---|
| Before preflight passes | Nothing is changed; no rollback needed |
| Steps 1–6, tag **not yet** pushed | Local tag deleted, repository reset to starting commit, `appcast.xml` removed if new |
| Tag already pushed (step 6 or 7) | **Nothing is rolled back.** Script prints which step to re-run |

If the tag has been pushed but Release creation failed, resume with:
```bash
bash scripts/release/publish-github-release.sh --version 1.5.0
bash scripts/release/publish-appcast.sh        --version 1.5.0
```

#### 0. Preflight checks

Verifies that tools, git status, permissions, and configuration are ready.

```bash
bash scripts/release/preflight-check.sh --scheme WOA --project src/WOA.xcodeproj
```

| Option | Meaning |
|---|---|
| `--scheme <name>` | Xcode scheme (**required**) |
| `--project <path>` / `--workspace <path>` | One of them is **required** |
| `--main-branch <name>` | Default `main` |
| `--remote <name>` | Default `origin` |
| `--sparkle-bin <dir>` | Optional; path to Sparkle tools |

#### 1. Bump the version

Calculates the next version and updates `project.pbxproj` (MARKETING_VERSION and CURRENT_PROJECT_VERSION in all targets/configurations).

```bash
# Calculate and write the next minor version
bash scripts/release/version-bump.sh --project src/WOA.xcodeproj

# Capture the version
VERSION="$(bash scripts/release/version-bump.sh --project src/WOA.xcodeproj)"

# Next major version
bash scripts/release/version-bump.sh --project src/WOA.xcodeproj --new-major

# Force a specific version
bash scripts/release/version-bump.sh --project src/WOA.xcodeproj --version 2.0.0

# Only print the version without editing
bash scripts/release/version-bump.sh --no-write
```

**Output:** The version on stdout (e.g., `1.5.0`).

| Option | Meaning |
|---|---|
| `--project <path>` | `.xcodeproj` path |
| `--workspace <path>` | Workspace path; must contain exactly one `project.pbxproj` |
| `--pbxproj <path>` | Explicit `project.pbxproj` path |
| `--version <x.y.z>` | Use this version instead of calculating |
| `--new-major` | Bump major instead of minor |
| `--no-write` | Calculate and print, do not edit anything |
| `--remote <name>` | Used to check the tag is free (default `origin`) |

#### 2. Build in Release configuration

Runs `xcodebuild clean archive` to produce the Xcode archive. This is unchanged to maintain compatibility with CI/CD systems like Codemagic.

```bash
bash scripts/release/build-in-release.sh --scheme WOA --project src/WOA.xcodeproj \
    --version 1.5.0 --archive-path build/archive/WOA-1.5.0.xcarchive
```

| Option | Meaning |
|---|---|
| `--scheme <name>` | Xcode scheme (**required**) |
| `--project <path>` / `--workspace <path>` | One of them is **required** |
| `--configuration <name>` | Default `Release` |
| `--archive-path <path>` | Default `build/archive/<scheme>.xcarchive` |
| `--version <version>` | Sets MARKETING_VERSION and CURRENT_PROJECT_VERSION for the build |
| `--code-signing-allowed <YES\|NO>` | Default `YES`; set to `NO` for unsigned builds |

#### 3. Package artifacts

Extracts the app from the archive and creates `.app`, `.app.zip`, and `.dmg` in `dist/`. Verifies version numbers match.

```bash
bash scripts/release/package-artifacts.sh \
    --archive-path build/archive/WOA-1.5.0.xcarchive \
    --version 1.5.0 --app-name WOA
```

**Output:** 
- `dist/WOA.app` — the extracted application
- `dist/WOA-1.5.0.app.zip` — used by Sparkle and GitHub Release
- `dist/WOA-1.5.0.dmg` — for manual downloads

| Option | Meaning |
|---|---|
| `--archive-path <path>` | The `.xcarchive` (**required**) |
| `--version <x.y.z>` | Expected version (**required**) |
| `--app-name <name>` | App name without `.app` (default: auto-detect) |
| `--export-options-plist <path>` | Use `xcodebuild -exportArchive` instead of copying |
| `--build-dir <path>` | Default `build` |
| `--dist-dir <path>` | Default `dist` |

#### 4. Sign for Sparkle

Signs the zip with Sparkle's private key and adds a new entry to `appcast.xml` (modified in working tree, not committed yet).

```bash
bash scripts/release/sparkle-sign.sh --version 1.5.0

# With an exported private key (for CI/CD)
bash scripts/release/sparkle-sign.sh --version 1.5.0 --ed-key-file ./sparkle_ed_key
```

Before signing, validates:
- `CFBundleVersion` in Info.plist
- `SUPublicEDKey` format in Info.plist
- `SUFeedURL` matches expected value
- `Sparkle.framework` is embedded
- Code signature on the app

After signing, validates:
- Exactly one new entry added to `appcast.xml`
- Entry has `sparkle:edSignature`
- Enclosure URL matches expected GitHub Release prefix
- XML is well-formed

**To undo before step 5:**
```bash
git checkout -- appcast.xml
```

| Option | Meaning |
|---|---|
| `--version <x.y.z>` | Default: from zip in `--dist-dir`, else latest tag |
| `--app-path <path>` | Default: the single `.app` in `--dist-dir` |
| `--zip-path <path>` | Default: `<dist-dir>/*-<version>.app.zip` |
| `--dist-dir <path>` | Default `dist` |
| `--build-dir <path>` | Default `build` |
| `--repository <owner/name>` | Default: detected with `gh` |
| `--main-branch <name>` | Used for default feed URL (default `main`) |
| `--appcast-path <path>` | Default `appcast.xml` |
| `--feed-url <url>` | Expected `SUFeedURL` |
| `--sparkle-bin <dir>` | Folder containing `generate_appcast` |
| `--ed-key-file <path>` | EdDSA private key file; default is login Keychain |

#### 5. Commit and tag

Creates one release commit with the version bump and `appcast.xml`, then creates the annotated tag `vX.Y.Z`. Everything stays local (not pushed).

```bash
bash scripts/release/commit-and-tag.sh --version 1.5.0
```

The commit message is `chore: release vX.Y.Z`.

Safeguards:
- Must be on `main`
- Tag must not exist
- `appcast.xml` must already contain the version
- Only `project.pbxproj` and `appcast.xml` may be modified

**To undo before step 6:**
```bash
git tag -d vX.Y.Z
git reset --hard <commit before>
```

| Option | Meaning |
|---|---|
| `--version <x.y.z>` | Default: from zip in `--dist-dir`, else latest tag |
| `--dist-dir <path>` | Only used to detect version (default `dist`) |
| `--appcast-path <path>` | Default `appcast.xml` |
| `--main-branch <name>` | Branch that must be checked out (default `main`) |

#### 6. Publish to GitHub

Pushes the tag to GitHub and creates the Release with zip and dmg artifacts. The commit is **not** pushed to `main` yet.

```bash
bash scripts/release/publish-github-release.sh --version 1.5.0

# Simulate without creating anything
bash scripts/release/publish-github-release.sh --version 1.5.0 --dry-run
```

Idempotent: If the remote already has the identical tag, it is not pushed again. If the Release already exists, the script stops with instructions.

| Option | Meaning |
|---|---|
| `--version <x.y.z>` | Default: from zip in `--dist-dir`, else latest tag |
| `--dist-dir <path>` | Default `dist` |
| `--remote <name>` | Default `origin` |
| `--dry-run` | Simulate the push, print the command, create nothing |

#### 7. Publish the appcast feed

Pushes the tagged commit to `main` to make the update live for installed apps.

```bash
bash scripts/release/publish-appcast.sh --version 1.5.0

# Simulate without pushing
bash scripts/release/publish-appcast.sh --version 1.5.0 --dry-run
```

Before pushing, verifies:
- Tag exists and its commit contains `appcast.xml` with the version
- GitHub Release exists and has the `*-X.Y.Z.app.zip` asset
- Asset URL is reachable (best-effort warning)
- `main` can be fast-forwarded to the tagged commit

**Note:** `raw.githubusercontent.com` caches files for a few minutes, so the new appcast may not be visible immediately.

| Option | Meaning |
|---|---|
| `--version <x.y.z>` | Default: from zip in `--dist-dir`, else latest tag |
| `--dist-dir <path>` | Default `dist` |
| `--repository <owner/name>` | Default: detected with `gh` |
| `--remote <name>` | Default `origin` |
| `--main-branch <name>` | Default `main` |
| `--appcast-path <path>` | Default `appcast.xml` |
| `--dry-run` | Simulate the push, run all checks |

### Running steps by hand

If you prefer to run each step individually instead of using the orchestrator:

```bash
bash scripts/release/preflight-check.sh --scheme WOA --project src/WOA.xcodeproj

VERSION="$(bash scripts/release/version-bump.sh --project src/WOA.xcodeproj)"

bash scripts/release/build-in-release.sh --scheme WOA --project src/WOA.xcodeproj \
    --version "$VERSION" --archive-path "build/archive/WOA-${VERSION}.xcarchive"

bash scripts/release/package-artifacts.sh --archive-path "build/archive/WOA-${VERSION}.xcarchive" \
    --version "$VERSION" --app-name WOA

bash scripts/release/sparkle-sign.sh        --version "$VERSION"
bash scripts/release/commit-and-tag.sh      --version "$VERSION"
bash scripts/release/publish-github-release.sh --version "$VERSION"
bash scripts/release/publish-appcast.sh     --version "$VERSION"
```

Because later steps default to the version found in `dist/`, steps 4–7 also work without `--version` right after step 3.

## Code signing

WOA uses a self-signed certificate for code signing. This keeps the app's designated requirement consistent across updates.

### Create a signing certificate

```bash
bash scripts/tools/create-signing-certificate.sh --backup-p12 ~/CrixoDev-backup.p12
```

This creates a self-signed certificate, imports it into your login Keychain, and optionally backs it up as a `.p12` file.

Options:

| Option | Meaning |
|--------|---------|
| `--identity <name>` | Certificate common name (default `CrixoDev`) |
| `--days <n>` | Validity in days (default 3650) |
| `--keychain <path>` | Target keychain (default: login keychain) |
| `--backup-p12 <path>` | Write a password-protected `.p12` backup |
| `--force` | Replace an existing identity (changes designated requirement) |

The certificate is stored only in your Keychain on that Mac. If you need to sign on a different machine, import the `.p12` backup first.

For detailed information, see [Code-signing certificate](SIGNING-CERTIFICATE.md).

### Hardened Runtime and Library Validation

**Issue:** The application failed to launch in Release mode if Hardened Runtime was enabled while the app and embedded Sparkle framework were only ad-hoc signed. During startup, macOS performs library validation and rejected the embedded Sparkle.framework, reporting a code-signing mismatch.

**Current solution:** Hardened Runtime is disabled (ENABLE_HARDENED_RUNTIME = NO) for Release builds, which disables library validation checks. This is acceptable for unsigned internal/development builds but not recommended for public distribution.

**Production fix:** A proper production solution would be to sign the application and all embedded frameworks with a valid Developer ID certificate and keep Hardened Runtime enabled. This is outside the scope of local development but should be considered before distributing the app outside your organization.

## Install from GitHub Releases

1. Go to [github.com/crixo/woa-swift/releases](https://github.com/crixo/woa-swift/releases).
2. Download the latest `.dmg` or `.app.zip`.
3. For DMG: mount it and drag **WOA** to **Applications**.
4. For ZIP: extract and move **WOA.app** to **Applications**.
5. Launch from **Applications**, or search for it in Spotlight.

### Gatekeeper warning

Since the app is not notarized, macOS shows "unidentified developer" on first run. Click **Open** to proceed.

If the app was not code-signed or was signed with a certificate unknown to macOS:

```bash
xattr -dr com.apple.quarantine /Applications/WOA.app
```

## Check for updates

WOA checks for updates automatically via Sparkle on launch and periodically while running. Users can also manually check for updates in the application menu.

Updates are staged in a temporary location and installed on the next launch. Users are notified when a new version is available.

For Sparkle configuration, see [Sparkle](sparkle.md).

## Troubleshooting

### "Command not found" or permission errors

Ensure scripts are executable:

```bash
chmod +x scripts/release/*.sh
chmod +x scripts/tools/*.sh
chmod +x scripts/test.sh
```

### Build and release troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Uncommitted changes found` (step 0) | Commit or stash; the release needs a clean tree |
| `Tag already exists` (step 1) | The next version is taken. Use `--version` to force a different version, or delete the stale tag |
| `CFBundleVersion is 'x', expected 'y'` (step 3 or 4) | `Info.plist` does not use `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` |
| `SUPublicEDKey is missing or invalid` (step 4) | Run Sparkle's `generate_keys` and add the public key to `Info.plist` |
| `generate_appcast not found` (step 4) | Use `--sparkle-bin`, set `$SPARKLE_BIN`, or build once so SwiftPM fetches Sparkle |
| `has no edSignature` (step 4) | The EdDSA private key is not in Keychain; use `--ed-key-file` with an exported key |
| `Unexpected change in the working tree` (step 5) | Only `project.pbxproj` and `appcast.xml` may be modified; commit or discard other changes |
| `Cannot push` (step 7) | `main` is protected or has moved. The tag and Release already exist; resolve the conflict, then re-run step 7 |
| Asset download URL does not answer (step 7 warning) | Repository is private; Sparkle needs a publicly downloadable URL |
| Zip file name contains spaces | GitHub renames such assets; use a name without spaces in the app name |

### Keychain and signing issues

#### Keychain password prompt during release

This happens during code signing. When prompted, choose **Always Allow** to avoid repeated prompts for each operation.

#### "Keychain certificate not found"

The certificate name must match `DEFAULT_SIGN_IDENTITY` in `scripts/release/release-common.sh`, which is `CrixoDev` by default. Create the certificate using:

```bash
bash scripts/tools/create-signing-certificate.sh
```

### Build configuration issues

#### Build fails with "Cannot find framework in SDK"

Ensure you have set a development team under Signing & Capabilities in Xcode. The app requires code signing to build.

#### Hardened Runtime errors during Release build

If the app fails to launch with code-signing errors about Sparkle.framework, Hardened Runtime is currently disabled for Release builds. This is a known limitation; see [Hardened Runtime and Library Validation](#hardened-runtime-and-library-validation) above.

### Database and testing issues

#### Tests fail with "Cannot open database"

Tests use temporary directories and do not access the installed application database. If tests fail with database errors, delete the scratch directory and run tests again:

```bash
rm -rf "${TMPDIR:-/tmp}/woa-swift-tests-$UID"
bash scripts/test.sh
```

#### Application crashes on launch

Check the system log:

```bash
log stream --predicate 'process == "WOA"'
```

For database-related issues, see [Database selection and storage](database-lifecycle.md).

### Resuming a failed release

If a release fails after the tag has been pushed (step 6 or 7), nothing is rolled back. The script prints which step to re-run:

```bash
# If Release creation failed
bash scripts/release/publish-github-release.sh --version 1.5.0

# If appcast feed push failed
bash scripts/release/publish-appcast.sh --version 1.5.0
```
