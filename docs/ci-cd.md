# CI/CD

Codemagic configuration is in [`codemagic.yaml`](../codemagic.yaml). These
workflows build artifacts; the YAML does not publish the GitHub Release or the
Sparkle appcast. Local release publication is handled by
[`scripts/release/full-release-orchestration.sh`](../scripts/release/full-release-orchestration.sh).

## Workflows as checked in

| Workflow | Trigger | Configured work | Artifact patterns |
|---|---|---|---|
| `woa-ci-build` | Push and pull request on any branch | Resolve packages; unsigned Debug macOS build | `build/**/*.log` |
| `woa-release-build` | Tag matching `v*` | Resolve packages; call `build-in-release.sh` | `build/*.pkg`, `build/*.dmg`, `build/*.xcarchive`, logs |
| `woa-release-standard` | Tag matching `v*` | Resolve packages; unsigned archive; extract app; create DMG | Archive, app, DMG, and logs under `build/` |

All use the `WOA` scheme, `src/WOA.xcodeproj`, and Codemagic's latest Xcode
image. CI is configured on `mac_mini_m2`.

## Known release-workflow gaps

The checked-in `woa-release-build` invokes
`scripts/release/build-in-release.sh` with `--app-name`, which that script does
not accept. The script creates an archive only; it does not create the
configured `.pkg` or `.dmg` artifacts. Do not treat this workflow as a
successful signed release pipeline without correcting and verifying the
configuration.

`woa-release-standard` invokes the archive script with
`--code-signing-allowed NO`, then creates an unsigned app and DMG. It does not
create a PKG, GitHub Release, or appcast update.

The commented signing-group example in `codemagic.yaml` is not active
configuration. No certificate/profile group is currently enabled there.

## Run CI-equivalent build locally

```bash
xcodebuild -resolvePackageDependencies \
  -project src/WOA.xcodeproj -scheme WOA

xcodebuild build \
  -project src/WOA.xcodeproj \
  -scheme WOA \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```

Run the database regression suite separately with `bash scripts/test.sh`.
Codemagic's `woa-ci-build` does not invoke that test script.

## Release publication

The local orchestration script performs preflight, archive and package
creation, code signing, Sparkle appcast signing, local commit/tag creation,
GitHub Release creation, and appcast publication. It requires a clean,
synchronized main branch and authenticated GitHub CLI access. Its dry-run still
builds and packages locally and then rolls back local Git changes. See
[Build, release, and installation](build-and-release.md) before running it.

## Troubleshooting

- **Package resolution fails:** run the `xcodebuild -resolvePackageDependencies`
  command above and inspect Xcode's package-resolution output.
- **Unsigned Debug build fails:** inspect the Codemagic build log; confirm the
  WOA project, shared scheme, local `Secrets.xcconfig` requirement, and SDK
  configuration.
- **Release workflow fails on `--app-name`:** this is a checked-in workflow /
  script interface mismatch; the script has no such option.
- **Expected artifacts are absent:** the standard workflow only creates an
  archive, extracted app, and DMG; `woa-release-build` currently has no
  packaging step for the declared `.pkg` or `.dmg` patterns.
- **Codemagic artifacts are not published to GitHub:** this is expected;
  publishing is only implemented in the local release orchestration scripts.

## Related guides

- [Build, release, and installation](build-and-release.md)
- [Code-signing certificate](SIGNING-CERTIFICATE.md)
- [Sparkle](sparkle.md)
