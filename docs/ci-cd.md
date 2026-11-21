# CI/CD — Continuous Integration and Deployment

WOA uses Codemagic for continuous integration and automated release builds.

## Overview

| Workflow | Trigger | Purpose | Output |
|---|---|---|---|
| `woa-ci-build` | Push or pull request | Validate every commit builds successfully | Build logs |
| `woa-release-build` | Tag matching `v*` | Build, sign, and package a release | DMG, PKG, XCArchive |
| `woa-release-standard` | Tag matching `v*` | Generate unsigned build artifacts for testing | DMG, XCArchive |

## CI Build Workflow

**Trigger:** Any push or pull request to any branch

**Steps:**
1. Resolve Swift Package dependencies
2. Build in Debug configuration (unsigned)

**Output:** Build logs (retained for debugging)

**Success:** Build completes without errors

## Release Build Workflow

**Trigger:** Git tag matching `v*` pattern (e.g., `v1.0.0`)

**Steps:**
1. Resolve Swift Package dependencies
2. Build, archive, and package via `scripts/release/build-in-release.sh`
3. Outputs: DMG and PKG installers, XCArchive

**Output:** Signed artifacts ready for GitHub Release

**Setup:** Requires Codemagic code-signing configuration (certificate and provisioning profile group)

## Standard Release Workflow

**Trigger:** Git tag matching `v*` pattern

**Steps:**
1. Resolve Swift Package dependencies
2. Create build directories
3. Archive application (unsigned, Debug configuration)
4. Extract app from archive
5. Create DMG from extracted app

**Output:** Unsigned DMG and XCArchive for testing

**Purpose:** Allows testing release artifacts before signing

## Configuration

Codemagic configuration is defined in [`codemagic.yaml`](../codemagic.yaml) at the repository root.

### Key variables

| Variable | Purpose |
|---|---|
| `XCODE_PROJECT` | Path to Xcode project: `src/WOA.xcodeproj` |
| `XCODE_SCHEME` | Build scheme: `WOA` |
| `instance_type` | Build machine: `mac_mini_m2` |
| `max_build_duration` | Maximum build time in minutes (30 for CI, 60 for release) |

### Code signing configuration

Release builds require:

1. A code-signing identity (certificate)
2. A provisioning profile group named in the workflow

Configure these in the Codemagic UI under **Code signing identities**.

Refer to [Code-signing certificate](SIGNING-CERTIFICATE.md) for certificate creation and management.

## Triggering a release

1. Bump the version in `src/WOA.xcodeproj/project.pbxproj` (or use `scripts/release/version-bump.sh`)
2. Create a git tag: `git tag v1.2.3`
3. Push the tag: `git push origin v1.2.3`
4. Codemagic automatically picks up the tag and runs the release workflow
5. Monitor the build in the Codemagic UI
6. Once complete, artifacts are available for download

## Local release alternative

If you prefer to build and release locally without Codemagic:

```bash
bash scripts/release/full-release-orchestration.sh
```

This script runs all release steps locally: version bump, build, sign, package, and GitHub Release creation. For details, see [Build, release, and installation](build-and-release.md).

## Troubleshooting

### Build fails with "Package dependencies could not be resolved"

Check Swift Package Manager dependencies in Xcode:
```bash
xcodebuild -resolvePackageDependencies -project src/WOA.xcodeproj -scheme WOA
```

### Code signing fails during release build

Verify the certificate and provisioning profile are configured in Codemagic under **Code signing identities**. Refer to [Code-signing certificate](SIGNING-CERTIFICATE.md).

### Artifacts are missing or incomplete

Check the build logs in the Codemagic UI. Ensure the build duration limit (`max_build_duration`) is not exceeded. If the build timed out, increase the limit.

## See also

- [Build, release, and installation](build-and-release.md) — Local build and release procedures
- [Code-signing certificate](SIGNING-CERTIFICATE.md) — Creating and managing certificates
- [Sparkle auto-update framework](sparkle.md) — Update feed configuration
