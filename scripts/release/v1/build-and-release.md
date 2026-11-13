# Build, release, and installation

WOA is a macOS Xcode project. The commands below run from the repository root.

## Build locally

### Xcode

1. Open [`src/WOA.xcodeproj`](../src/WOA.xcodeproj).
2. Select the **WOA** scheme.
3. For a signed local run, set a development team under **Signing &
   Capabilities**.
4. Choose **Product → Build** or **Product → Run**.

Xcode places products in its DerivedData build products directory. Use
**Product → Show Build Folder** to locate them.

### Command line

An unsigned Debug build for local verification can be built with:

```bash
xcodebuild \
  -project src/WOA.xcodeproj \
  -scheme WOA \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

For a signed build, configure the signing team and omit
`CODE_SIGNING_ALLOWED=NO`. Do not use the release-publishing script as a
substitute for a normal local build; it synchronizes Git branches and prepares
release artifacts.

## Run automated tests

The focused regression harness runs with Swift Package Manager and does not
launch the app. Use the wrapper to keep test builds separate from editor
indexing:

```bash
bash scripts/test.sh
```

See the [testing strategy](testing.md) for covered behavior and guidelines for
adding tests with new features.

## Automated release script

[`scripts/build-tag-release.sh`](../scripts/build-tag-release.sh) builds a
Release archive, validates the app bundle, and creates a ZIP and DMG. It also
supports creating and publishing the Git tag and GitHub Release.
The archive step is shared with [`scripts/build-in-release.sh`](../scripts/build-in-release.sh),
which defaults to the Release configuration and can also be run directly with
an Xcode scheme and project or workspace.

Before running it:

- Run on macOS with Xcode, Git, `hdiutil`, `gh`, and the other standard
  command-line tools installed.
- Have the configured Git remote and authenticated GitHub CLI available. The
  script checks for GitHub write permission.
- Commit or stash all changes. The script refuses a dirty worktree, fetches the
  remote, and updates/switches to the configured main branch (default `main`).
- Preserve anything important in the default `build/` and `dist/` directories.
  The script removes both directories before generating artifacts; this also
  happens in dry-run mode.

Start with a dry run:

```bash
bash scripts/build-tag-release.sh \
  --scheme WOA \
  --project src/WOA.xcodeproj \
  --app-name WOA \
  --dry-run
```

The dry run still fetches/synchronizes Git, builds and validates the release
artifacts, and writes to `build/` and `dist/`. It does not create a local tag,
push a tag, create a GitHub Release, or upload artifacts.

After reviewing the dry-run output and confirming the correct branch and
version, run the same command without `--dry-run` to publish. The script
increments the minor version by default; `--new-major` selects a major version
bump. Publishing creates an annotated tag on the main branch, pushes it, then
creates a GitHub Release with the app ZIP and DMG. This changes remote GitHub
state.

The script's default artifact directories are `build/` for archives and
intermediate files and `dist/` for the `.app`, ZIP, and DMG. Use
`--build-dir` or `--dist-dir` only after confirming the chosen directories do
not contain data that should be kept.
Use `--export-options-plist <path>` when the archive must be exported using a
specific Xcode `ExportOptions.plist`; otherwise, the script copies the app from
the archive.

## CI builds

[`codemagic.yaml`](../codemagic.yaml) defines a Debug CI build and release
workflows. The `woa-ci-build` workflow resolves Swift packages and builds the
WOA scheme unsigned for macOS. Both release workflows use
[`scripts/build-in-release.sh`](../scripts/build-in-release.sh) for archiving:
`woa-release-standard` then extracts the app and creates a DMG, while
`woa-release-build` invokes the tag-release script to prepare and publish
release artifacts.

## Install a published release

[`scripts/install-woa-swift.sh`](../scripts/install-woa-swift.sh) downloads the
ZIP asset for a GitHub release tag and installs its app bundle in
`/Applications`. The installer uses `sudo`, requires the current app to be
quit, validates the staged app, and attempts to restore the previous version
if activation fails.

For example:

```bash
bash scripts/install-woa-swift.sh v0.2.0
```

The script currently accepts a version argument and selects a `.zip` release
asset; its comments mention `--dmg`, but that option is not implemented. It also
looks for `./unlock-woa.sh` relative to the current working directory, whereas
the checked-in helper is at `scripts/unlock-woa.sh`. If Gatekeeper blocks an
app from a release you trust, the helper can be run explicitly:

```bash
bash scripts/unlock-woa.sh /Applications/WOA.app
```

That helper removes the quarantine attribute using `sudo`; only use it for an
application whose source and release you trust. It does not replace code
signing or notarization.
