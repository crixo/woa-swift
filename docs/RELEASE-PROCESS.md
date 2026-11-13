# Release process

How a new version of the app is built, tagged, published on GitHub and delivered to users through Sparkle.

The process is split into **one script per step**. Every script can be run on its own, and `full-release-orchestration.sh` runs them all in the right order.

All scripts live in `scripts/`. Relative paths passed to them (`--project`, `--dist-dir`, ...) are relative to the **repository root**.

---

## 1. The idea in one paragraph

The tag of a release must contain `appcast.xml`. The appcast needs the **signature of the final zip**, and the zip is only available after the build. So the zip is built and signed first, then **one commit** holding the version bump and the updated `appcast.xml` is created and **tagged**. The Release is created from that tag, and only at the very end the commit is pushed to `main`, which is when installed apps start seeing the update (the feed is read from `main`).

This works before the GitHub Release exists because the download URL of a Release asset is predictable:

```
https://github.com/<owner>/<repo>/releases/download/vX.Y.Z/<zip file name>
```

---

## 2. Flow

```
 0 preflight-check.sh          verify tools, git, GitHub, scheme
 1 version-bump.sh             next version  -> project.pbxproj        (working tree)
 2 build-in-release.sh         xcodebuild archive                      (build/archive/)
 3 package-artifacts.sh        .app  .app.zip  .dmg                    (dist/)
 4 sparkle-sign.sh             sign zip, add entry to appcast.xml      (working tree)
 5 commit-and-tag.sh           ONE commit: pbxproj + appcast.xml, then tag   (local)
 6 publish-github-release.sh   push the tag, create the Release with zip + dmg
 7 publish-appcast.sh          push the tagged commit to main          (feed goes live)
```

| Step | Changes the working tree | Changes git history | Touches the network |
|---|---|---|---|
| 0 | no (fast-forwards `main`) | no | fetch |
| 1 | `project.pbxproj` | no | reads tags |
| 2 | `build/` | no | no |
| 3 | `dist/`, `build/` | no | no |
| 4 | `appcast.xml` | no | no |
| 5 | no | commit + local tag | no |
| 6 | no | no | pushes tag, creates Release |
| 7 | no | no | pushes commit to `main` |

Until step 6 nothing is published. Between 6 and 7 the Release exists but the feed still serves the old appcast, so users never see an update that points at a missing file.

---

## 3. Prerequisites

Tools: `git`, `gh` (authenticated: `gh auth login`), `xcodebuild`, `hdiutil`, `ditto`, `sed`, `grep`, `awk`, `find`. macOS only. Sparkle's `generate_appcast` is needed by step 4 (see that step for how it is located).

Project setup:

- `Info.plist` uses `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`. `project.pbxproj` is the single source of truth for the version.
- `Info.plist` contains `SUPublicEDKey` (from Sparkle's `generate_keys`) and `SUFeedURL`.
- `SUFeedURL` should be `https://raw.githubusercontent.com/<owner>/<repo>/main/appcast.xml` (or whatever you pass as `--feed-url` / `--appcast-path`).
- Sparkle is embedded in the app (`Sparkle.framework`).
- The GitHub repository is public, otherwise Sparkle cannot download the zip.
- You are on `main`, the working tree is clean, and the tag `vX.Y.Z` of the next version does not exist.

Versioning: the next version is derived from the latest `vX.Y.Z` tag. Minor bump by default (`1.4.3 → 1.5.0`), major bump with `--new-major` (`1.4.3 → 2.0.0`). With no tag at all it starts from `v0.0.0`.

---

## 4. Files and responsibilities

| File | Responsibility |
|---|---|
| `release-common.sh` | Shared helpers (logging, error trap, version resolution, artifact lookup, Sparkle helpers). Sourced by the others, never executed. |
| `preflight-check.sh` | Step 0. Verifies that a release can start. |
| `version-bump.sh` | Step 1. Calculates the version and writes it into `project.pbxproj`. |
| `build-in-release.sh` | Step 2. Produces the Xcode archive. Also used by `codemagic.yaml`; unchanged. |
| `package-artifacts.sh` | Step 3. Turns the archive into `.app`, `.app.zip`, `.dmg`. |
| `sparkle-sign.sh` | Step 4. Signs the zip and updates `appcast.xml`. |
| `commit-and-tag.sh` | Step 5. Creates the release commit and the tag, locally. |
| `publish-github-release.sh` | Step 6. Pushes the tag and creates the GitHub Release. |
| `publish-appcast.sh` | Step 7. Pushes the release commit to `main`. |
| `full-release-orchestration.sh` | Runs steps 0 to 7, forwards options, rolls back on failure. |

Conventions shared by all scripts:

- Logs go to **stderr**; stdout is reserved for machine-readable output (only `version-bump.sh` prints something there: the version).
- `--help` prints the options of each script.
- When `--version` is omitted, a script uses the single `*-X.Y.Z.app.zip` found in `dist/`, and if there is none, the latest `vX.Y.Z` tag.
- Compatible with the bash 3.2 shipped with macOS.

---

## 5. Step by step

### Step 0: `preflight-check.sh`

**Responsibility:** make sure a release can start, before anything is changed.

Checks: required tools; remote exists; current branch is `main`; working tree is clean; local `main` is fast-forwarded and equals the remote; `gh` is authenticated and has WRITE/MAINTAIN/ADMIN permission; the Xcode scheme exists and is shared. It only warns if `generate_appcast` cannot be found yet.

```bash
./scripts/release/preflight-check.sh --scheme WOA --project src/WOA.xcodeproj
```

| Option | Meaning |
|---|---|
| `--scheme <name>` | Xcode scheme (required) |
| `--project <path>` / `--workspace <path>` | One of them is required |
| `--main-branch <name>` | Default `main` |
| `--remote <name>` | Default `origin` |
| `--sparkle-bin <dir>` | Only used for the warning |

### Step 1: `version-bump.sh`

**Responsibility:** decide the version and write it into `project.pbxproj` (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, every target and configuration). It commits nothing. It also refuses to continue if the tag already exists locally or on the remote, or if a GitHub Release already exists for it.

**Output:** the version on stdout (e.g. `1.5.0`).

```bash
# calculate and write the next minor version
./scripts/release/version-bump.sh --project src/WOA.xcodeproj

# capture it
VERSION="$(./scripts/release/version-bump.sh --project src/WOA.xcodeproj)"

# next major
./scripts/release/version-bump.sh --project src/WOA.xcodeproj --new-major

# force a version
./scripts/release/version-bump.sh --project src/WOA.xcodeproj --version 2.0.0

# only print the version, edit nothing
./scripts/release/version-bump.sh --no-write
```

| Option | Meaning |
|---|---|
| `--project <path>` | `.xcodeproj`; `project.pbxproj` is derived from it |
| `--workspace <path>` | Repo must then contain exactly one `project.pbxproj` |
| `--pbxproj <path>` | Explicit `project.pbxproj` |
| `--version <x.y.z>` | Use this version instead of calculating it |
| `--new-major` | Bump major instead of minor |
| `--no-write` | Calculate and print, edit nothing |
| `--remote <name>` | Used to check the tag is free (default `origin`) |

### Step 2: `build-in-release.sh`

**Responsibility:** create the Xcode archive (`xcodebuild clean archive`, `generic/platform=macOS`). Unchanged, so `codemagic.yaml` keeps working.

```bash
./scripts/release/build-in-release.sh --scheme WOA --project src/WOA.xcodeproj \
    --version 1.5.0 --archive-path build/archive/WOA-1.5.0.xcarchive
```

| Option | Meaning |
|---|---|
| `--scheme <name>` | Required |
| `--project <path>` / `--workspace <path>` | One of them is required |
| `--configuration <name>` | Default `Release` |
| `--archive-path <path>` | Default `build/archive/<scheme>.xcarchive` |
| `--version <version>` | Sets `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` for the build |
| `--code-signing-allowed <YES\|NO>` | Sets `CODE_SIGNING_ALLOWED` |

The orchestrator calls it with `--archive-path build/archive/<scheme>-<version>.xcarchive`.

### Step 3: `package-artifacts.sh`

**Responsibility:** from the archive, produce the release files and verify the version baked into the app.

Output in `dist/` (the directory is recreated on every run):

```
dist/<name>.app
dist/<name>-<version>.app.zip      used by Sparkle and the Release
dist/<name>-<version>.dmg          for manual downloads
```

It checks that `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist` equal the release version, and that zip and dmg are not empty.

```bash
./scripts/release/package-artifacts.sh \
    --archive-path build/archive/WOA-1.5.0.xcarchive --version 1.5.0 --app-name WOA
```

| Option | Meaning |
|---|---|
| `--archive-path <path>` | The `.xcarchive` (required) |
| `--version <x.y.z>` | Expected version (required) |
| `--app-name <name>` | App name without `.app` (default: detected) |
| `--export-options-plist <path>` | Use `xcodebuild -exportArchive` instead of copying the `.app` from the archive |
| `--build-dir <path>` | Default `build` |
| `--dist-dir <path>` | Default `dist` |

### Step 4: `sparkle-sign.sh`

**Responsibility:** sign the zip with Sparkle's `generate_appcast` and add the new entry on top of `appcast.xml`, **in the working tree**. Nothing is committed.

Before touching `appcast.xml` it validates: `CFBundleVersion`, `SUPublicEDKey` (valid format), `SUFeedURL` (warns if different from the expected one), embedded `Sparkle.framework`, code signature (warning). After signing it validates: exactly one entry, `sparkle:edSignature` present, right version, enclosure URL starts with the Release download prefix and its file name equals the zip name, merged XML well-formed, exactly one more entry than before. Existing entries are left untouched. It stops if `appcast.xml` has uncommitted changes or already contains the version.

`generate_appcast` is searched in this order: `--sparkle-bin`, `$SPARKLE_BIN`, `PATH`, Xcode DerivedData (SwiftPM artifacts).

```bash
./scripts/release/sparkle-sign.sh --version 1.5.0

# CI, with an exported private key
./scripts/release/sparkle-sign.sh --version 1.5.0 --ed-key-file ./sparkle_ed_key
```

| Option | Meaning |
|---|---|
| `--version <x.y.z>` | Default: from the zip in `--dist-dir`, else latest tag |
| `--app-path <path>` | Default: the single `.app` in `--dist-dir` |
| `--zip-path <path>` | Default: `<dist-dir>/*-<version>.app.zip` |
| `--dist-dir <path>` | Default `dist` |
| `--build-dir <path>` | Default `build` |
| `--repository <owner/name>` | Default: detected with `gh` |
| `--main-branch <name>` | Used for the default feed URL (default `main`) |
| `--appcast-path <path>` | Default `appcast.xml` |
| `--feed-url <url>` | Expected `SUFeedURL` |
| `--sparkle-bin <dir>` | Folder containing `generate_appcast` |
| `--ed-key-file <path>` | EdDSA private key; default is the login Keychain |

To undo it before step 5: `git checkout -- appcast.xml` (or delete the file if it was new).

### Step 5: `commit-and-tag.sh`

**Responsibility:** create **one** commit (`chore: release vX.Y.Z`) with the version bump and `appcast.xml`, then create the annotated tag `vX.Y.Z` on it. Everything stays local.

Safeguards: must be on `main`; the tag must not exist; `appcast.xml` must already contain the version; only `project.pbxproj` and `appcast.xml` may be modified (anything else stops the script); after tagging it verifies that `git show vX.Y.Z:appcast.xml` contains the version.

```bash
./scripts/release/commit-and-tag.sh --version 1.5.0
```

| Option | Meaning |
|---|---|
| `--version <x.y.z>` | Default: from the zip in `--dist-dir`, else latest tag |
| `--dist-dir <path>` | Only used to detect the version (default `dist`) |
| `--appcast-path <path>` | Default `appcast.xml` |
| `--main-branch <name>` | Branch that must be checked out (default `main`) |

To undo it before step 6: `git tag -d vX.Y.Z && git reset --hard <commit before>`.

### Step 6: `publish-github-release.sh`

**Responsibility:** push the tag and create the GitHub Release with the zip and the dmg (`gh release create --verify-tag --generate-notes`). The commit is **not** pushed to `main` here.

Idempotent: if the remote already has the identical tag it is not pushed again; if it exists with different content, or the Release already exists, the script stops. If Release creation fails the tag is intentionally left on the remote and the script says how to re-run.

```bash
./scripts/release/publish-github-release.sh --version 1.5.0
./scripts/release/publish-github-release.sh --version 1.5.0 --dry-run
```

| Option | Meaning |
|---|---|
| `--version <x.y.z>` | Default: from the zip in `--dist-dir`, else latest tag |
| `--dist-dir <path>` | Default `dist` |
| `--remote <name>` | Default `origin` |
| `--dry-run` | Simulate the tag push, print the `gh release create` command, create nothing |

### Step 7: `publish-appcast.sh`

**Responsibility:** make the update live by pushing the tagged commit to `main` (`git push <remote> <tag commit>:refs/heads/main`).

Before pushing it verifies: the tag exists and its commit contains `appcast.xml` with the version; the GitHub Release exists and has the `*-X.Y.Z.app.zip` asset; the asset URL answers (best-effort warning); `main` can be fast-forwarded to the tagged commit. If `main` already contains the commit it exits successfully without doing anything.

```bash
./scripts/release/publish-appcast.sh --version 1.5.0
./scripts/release/publish-appcast.sh --version 1.5.0 --dry-run
```

| Option | Meaning |
|---|---|
| `--version <x.y.z>` | Default: from the zip in `--dist-dir`, else latest tag |
| `--dist-dir <path>` | Only used to detect the version (default `dist`) |
| `--repository <owner/name>` | Default: detected with `gh` |
| `--remote <name>` | Default `origin` |
| `--main-branch <name>` | Default `main` |
| `--appcast-path <path>` | Default `appcast.xml` |
| `--dry-run` | Run every check, simulate the push; a missing Release only warns |

`raw.githubusercontent.com` caches files for a few minutes, so the new appcast may not be visible immediately.

---

## 6. The orchestrator: `full-release-orchestration.sh`

**Responsibility:** decide the order, forward options to the step scripts, and undo the local changes if something fails before the tag is pushed. It contains no step logic of its own.

### Usage

```bash
# 1. rehearsal: builds and signs everything, simulates the pushes, rolls back
./scripts/release/full-release-orchestration.sh --scheme WOA --project src/WOA.xcodeproj --app-name WOA --dry-run

# 2. real release
./scripts/release/full-release-orchestration.sh --scheme WOA --project src/WOA.xcodeproj --app-name WOA

# other examples
./scripts/release/full-release-orchestration.sh --scheme WOA --project src/WOA.xcodeproj --new-major
./scripts/release/full-release-orchestration.sh --scheme WOA --workspace WOA.xcworkspace --ed-key-file ./sparkle_ed_key
```

### Options

| Option | Forwarded to | Meaning |
|---|---|---|
| `--scheme <name>` | 0, 2 | Xcode scheme (required) |
| `--project <path>` / `--workspace <path>` | 0, 1, 2 | One of them is required |
| `--app-name <name>` | 3 | App name without `.app` |
| `--export-options-plist <path>` | 3 | Export the archive with this plist |
| `--configuration <name>` | 2 | Default `Release` |
| `--main-branch <name>` | 0, 4, 5, 7 | Default `main` |
| `--remote <name>` | 0, 1, 6, 7 | Default `origin` |
| `--build-dir <path>` | 2, 3, 4 | Default `build` |
| `--dist-dir <path>` | 3 to 7 | Default `dist` |
| `--appcast-path <path>` | 4, 5, 7 | Default `appcast.xml` |
| `--version <x.y.z>` | 1 | Force the version |
| `--new-major` | 1 | Bump major instead of minor |
| `--skip-version-bump` | 1 | Do not write `project.pbxproj` (the build still gets the version as a build setting) |
| `--sparkle-bin <dir>` | 0, 4 | Folder containing `generate_appcast` |
| `--ed-key-file <path>` | 4 | EdDSA private key |
| `--feed-url <url>` | 4 | Expected `SUFeedURL` |
| `--repository <owner/name>` | 4, 7 | GitHub repository |
| `--dry-run` | 6, 7 | See below |

### Dry run

Runs steps 0 to 5 for real (build, package, sign, commit, tag), runs steps 6 and 7 with `--dry-run`, then **rolls back** the commit, the tag and `appcast.xml`. Nothing is pushed, tagged or released. `build/` and `dist/` are left in place for inspection. Because the Release does not exist yet, step 7 only warns about it.

### Rollback and recovery

| Where it fails | What happens |
|---|---|
| Before the pre-flight passes | Nothing was changed, nothing to undo |
| Steps 1 to 6, tag **not yet** on the remote | The local tag is deleted, the repository is reset to the commit it started from, and `appcast.xml` is removed if it was new |
| Tag already pushed (step 6 or 7 failed) | **Nothing is rolled back.** The script prints which step to re-run |
| The remote cannot be reached to tell | Local state is left untouched and a warning is printed |

Resuming after the tag has been pushed:

```bash
./scripts/release/publish-github-release.sh --version 1.5.0   # if the Release is missing
./scripts/release/publish-appcast.sh        --version 1.5.0   # to put the update feed live
```

---

## 7. Running the steps by hand

The same release, one step at a time:

```bash
./scripts/release/preflight-check.sh --scheme WOA --project src/WOA.xcodeproj

VERSION="$(./scripts/release/version-bump.sh --project src/WOA.xcodeproj)"

./scripts/release/build-in-release.sh --scheme WOA --project src/WOA.xcodeproj \
    --version "$VERSION" --archive-path "build/archive/WOA-${VERSION}.xcarchive"

./scripts/release/package-artifacts.sh --archive-path "build/archive/WOA-${VERSION}.xcarchive" \
    --version "$VERSION" --app-name WOA

./scripts/release/sparkle-sign.sh        --version "$VERSION"
./scripts/release/commit-and-tag.sh      --version "$VERSION"
./scripts/release/publish-github-release.sh --version "$VERSION"
./scripts/release/publish-appcast.sh     --version "$VERSION"
```

Because later steps default to the version found in `dist/`, steps 4 to 7 also work without `--version` right after step 3.

---

## 8. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Uncommitted changes found` (step 0) | Commit or stash; the release needs a clean tree |
| `Tag already exists` (step 1) | The next version is taken. Use `--version` or delete the stale tag |
| `CFBundleVersion is 'x', expected 'y'` (step 3 or 4) | `Info.plist` does not use `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` |
| `SUPublicEDKey is missing` (step 4) | Run Sparkle's `generate_keys` and add the public key to the target |
| `generate_appcast not found` (step 4) | Use `--sparkle-bin`, set `SPARKLE_BIN`, or build once so SwiftPM fetches Sparkle |
| `has no edSignature` (step 4) | The EdDSA private key is not in the Keychain; use `--ed-key-file` |
| `Unexpected change in the working tree` (step 5) | Something other than `project.pbxproj` / `appcast.xml` is modified |
| `Cannot push` the commit to `main` (step 7) | `main` is protected or has moved. The tag and Release already exist; resolve it, then re-run step 7 |
| Asset download URL does not answer (step 7 warning) | The repository is private; Sparkle needs a publicly downloadable URL |
| Zip file name contains spaces | GitHub renames such assets; use a name without spaces |

---

## 9. Codemagic

`build-in-release.sh` is unchanged and is the only script `codemagic.yaml` needs. The other scripts are meant for the machine that holds the Sparkle signing key and the GitHub credentials.
