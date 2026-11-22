---
name: bug-finder-ci-github-actions
description: Bug-hunting guidance for GitHub Actions workflows, composite actions, and release pipelines. Use when reviewing CI/CD files for concrete defects such as script injection, secret exposure, steps that do not fail the job, and unsafe release paths. Loaded by the Repository Bug Finder agent.
---

# Skill: CI/CD and release (GitHub Actions)

> Adds to the core agent. Cannot relax any core rule. Never trigger, re-run, or dispatch a workflow, and never contact GitHub or other external services.

## Activates on

`.github/workflows/**`, `.github/actions/**`, `**/action.yml`, `**/action.yaml`, `.github/dependabot.yml`

## Context to gather first

- The trigger (`on:`) of each workflow and who can cause it (forks, external contributors, labels, comments, schedules, manual dispatch).
- The `permissions:` at workflow and job level; which secrets and environments each job can reach.
- Which runner images, tool versions (Xcode, Swift, Node, Python), and matrix values are used, compared with `Package.swift`, project settings, scripts, and docs.
- Which scripts the workflow calls (they also activate their own skills).
- Release/tag/branch rules documented in the repository.

## Defect patterns

### Steps that do not do what they claim

- wrong `paths`/`branches`/`tags` filters so required checks never run or always skip;
- `if:` conditions that are always true/false, mis-scoped, or compare strings incorrectly (`if: github.event.inputs.flag` is a string, `'false'` is truthy);
- `continue-on-error: true`, `|| true`, or `fail-fast` settings that hide real failures on code that ships;
- steps whose failure does not fail the job (pipelines without `pipefail`: the default `bash -e {0}` shell on some runners lacks it unless `shell: bash` is explicit);
- test/build commands that run a different scheme, config, or destination than the one shipped;
- matrix entries that exclude the configuration that actually ships;
- jobs that `needs:` the wrong job so a release can proceed without tests;
- artifacts uploaded from a path that does not exist (silently empty with `if-no-files-found: ignore`) or downloaded under a mismatched name.

### Security

- script injection: untrusted values (`github.event.pull_request.title`, `head_ref`, `issue.body`, `comment.body`, branch names, commit messages) interpolated with `${{ … }}` directly into `run:` or `actions/github-script` code; the safe pattern passes them through `env:`;
- `pull_request_target` or `workflow_run` that checks out and executes untrusted PR code with secrets or write tokens;
- excessive `permissions:` (default write-all token, `contents: write`/`id-token: write` where unneeded) on jobs that run untrusted code;
- secrets exposed to forks or untrusted steps, echoed to logs, passed on command lines, or uploaded in artifacts/caches;
- third-party actions on mutable refs (`@main`, `@v1`) running with secrets, where the repository policy requires pinned SHAs or where the action is untrusted;
- `curl | sh`, unverified downloads of tools in the pipeline;
- self-hosted runners used for untrusted PRs.

### Release and signing

- release/publish jobs that can run without passing build and tests, or from the wrong ref (any branch, any tag pattern);
- version/build-number derived incorrectly (reused, non-monotonic, taken from an untrusted ref);
- signing, notarization, or stapling steps whose failure still produces an artifact that is published;
- certificate/keychain handling that leaves secrets on the runner or fails open;
- checksums/signatures computed before the artifact is modified, or not published.

### Determinism and consistency

- cache keys that omit lockfile hashes or toolchain versions (stale or cross-contaminated builds), or that restore caches across untrusted refs;
- tool, Xcode, Swift, runtime versions differing between CI, local scripts, manifests, and documentation, such that CI does not test the supported configuration;
- unpinned `runs-on: macos-latest`/`ubuntu-latest` where the repository requires a specific version;
- manifests and lockfiles that disagree (checked indirectly via what CI installs);
- concurrency groups that cancel release jobs, or that fail to cancel superseded PR runs where results would conflict.

### Dependabot / automation config

- ecosystems or directories that do not exist or omit ones in use (dependencies never updated), only when the repository states updates are expected.

## Safe validation

Only if already installed:

- `actionlint` on workflow files
- `yamllint` on YAML
- `shellcheck` on `run:` blocks extracted manually (read-only)
- `git log`/`git diff` for workflow history

Never run workflows locally with real secrets (e.g. `act` with a secrets file), never trigger or re-run workflows, and never call the GitHub API.

## Severity notes

- Critical: untrusted input reaching code execution with secrets or a write token; secret exposure; publishing an unsigned or unverified build.
- High: release path that bypasses tests or ships from the wrong ref; required checks that never run.
- Medium: failures hidden on non-shipping paths; stale caches; version mismatches between CI and documented support.
- Low: cosmetic workflow issues.

## Known false positives

- `${{ github.* }}` values that are not attacker-controlled (e.g. `github.sha`, `github.run_id`, `github.repository` in a non-fork-controlled context) used in `run:`.
- Mutable action refs for first-party actions in the same repository, or for actions in jobs with no secrets and read-only permissions, unless the repository mandates pinning.
- `continue-on-error` on explicitly experimental/nightly matrix legs that do not gate release.
- `pull_request_target` workflows that never check out or execute PR code (e.g. only labeling).
