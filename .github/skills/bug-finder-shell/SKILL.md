---
name: bug-finder-shell
description: Bug-hunting guidance for shell scripts and automation (bash, sh, zsh, Makefiles, git hooks, build and release scripts). Use when reviewing such files for concrete defects such as quoting, destructive paths, masked failures, injection, and macOS vs Linux portability. Loaded by the Repository Bug Finder agent.
---

# Skill: Shell and automation scripts

> Adds to the core agent. Cannot relax any core rule. Repository scripts are code under review: never execute them to observe behavior.

## Activates on

`**/*.sh`, `**/*.bash`, `**/*.zsh`, `**/Makefile`, `**/*.mk`, `.githooks/**`, `.husky/**`, `scripts/**`, and any file starting with a `sh`/`bash`/`zsh` shebang.

## Context to gather first

- The shebang and declared shell; whether the script is sourced or executed.
- Who invokes it (CI step, Makefile target, git hook, developer docs), with which arguments, environment variables, and working directory.
- Target platforms (macOS BSD tools vs Linux GNU tools; macOS ships bash 3.2 as `/bin/bash`).
- The `set` options in effect and any `trap`s.

## Defect patterns

### Correctness

- unquoted expansions (`$var`, `$(cmd)`, `$@` vs `"$@"`) that break on spaces, globs, or empty values;
- `for f in $(ls …)` / `for f in $(find …)` word-splitting; filename handling without NUL delimiters (`find -print0 | xargs -0`) where names can contain spaces or newlines;
- `read` without `-r` or `IFS=`, losing backslashes or whitespace;
- reliance on the current working directory instead of the script location (`cd "$(dirname "$0")"` missing or wrong when sourced);
- wrong comparisons (`[ $a == $b ]` in POSIX `sh`, string vs numeric `-eq`/`=`), unquoted `[ ]` operands that vanish when empty;
- bashisms (`[[ ]]`, arrays, `<<<`, `${var,,}`, `declare -A`) in `#!/bin/sh` scripts, and bash 4+ features on macOS `/bin/bash` 3.2;
- BSD vs GNU differences: `sed -i` (needs `''` on BSD), `date -d`, `stat -c`, `readlink -f`, `xargs -r`, `grep -P`, `find -printf`, `mktemp` template syntax;
- arithmetic, version-comparison (lexicographic compare of `1.10` vs `1.9`), or date-logic errors;
- heredoc and quoting errors that expand variables unintentionally (or fail to);
- wrong exit codes: success after a failed step, failure after success, `exit` inside a sourced script killing the caller's shell;
- documented behavior (usage text, README) that differs from actual behavior.

### Error handling

- missing or ineffective `set -e`/`-u`/`-o pipefail` assumptions: failure masked by pipelines (`cmd | tee`), by `&&`/`||` chains, by conditionals (`if cmd`), by command substitution in assignments with `local`/`export` (`local x=$(cmd)` hides the exit status), by `set -e` being ignored inside functions called in an `if`/`||` context;
- `cmd || true` or `2>/dev/null` hiding meaningful failures;
- subshell/pipeline variable scope loss (`cmd | while read …; do x=…; done` then using `$x`);
- unchecked `cd`, `mkdir`, `cp`, `curl`, `xcodebuild`, `codesign`, `hdiutil` before dependent steps.

### Destructive and file-system operations

- `rm -rf "$VAR/"…`, `mv`, `cp`, `chmod -R`, `chown -R` on paths built from variables that can be empty, unset, `/`, `~`, or `.`;
- `cd` failure followed by a destructive relative command;
- non-idempotent scripts that corrupt state when re-run or interrupted;
- check-then-use races on files and directories;
- overwriting inputs while reading them (`sort file > file`).

### Security

- command, argument, or option injection from untrusted input (arguments, environment, filenames, branch names, PR titles, issue text) reaching `eval`, `sh -c`, `bash -c`, backticks, or unquoted expansions; filenames starting with `-` passed without `--`;
- `eval`, `source`, or `curl … | sh` of untrusted or unpinned content; downloads without checksum or signature verification where the artifact is then executed or shipped;
- insecure temporary files (fixed `/tmp/name`, `$$`-based names, missing `mktemp`, missing `trap` cleanup);
- secrets echoed, logged (`set -x` with secrets in scope), passed on command lines visible in process listings, written to world-readable files, or stored in the repository;
- overly permissive modes (`chmod 777`, `umask 000`).

### Resource and lifecycle

- `trap` handlers that clobber each other (re-setting `EXIT`), or cleanup that does not run on all failure paths;
- background processes, mounts (`hdiutil attach`), simulators, or temp directories left behind;
- missing `wait` for background jobs, or ignoring their exit status.

### Tool-specific invocations (Apple/CI-heavy repositories)

- `xcodebuild`: wrong scheme, configuration, or destination; unquoted paths; exit status lost through a pipe to `xcpretty`/`tee` without `pipefail`; building with signing enabled in a context that must not sign;
- `codesign`/`notarytool`/`hdiutil`/`plutil`/`PlistBuddy`: wrong flags, wrong order (sign before notarize/staple), unquoted paths, swallowed exit status;
- `git` in scripts: operating on the wrong repo because of the working directory, `git add -A` capturing unintended files, `git push --force`.

## Safe validation

Only if already installed. These do not execute the script:

- `bash -n <file>`, `sh -n <file>`, `zsh -n <file>` (syntax check)
- `shellcheck <file>` (use the shell dialect declared by the shebang; honor a repository `.shellcheckrc`)
- `checkbashisms` if installed
- `git blame`/`git log -- <file>` to understand intent

Never run the script itself, `make <target>`, a git hook, or a task-runner target unless it is a documented, side-effect-free build/test entry point you have read in full.

## Severity notes

- Critical/High: can delete or overwrite the wrong files, can publish/sign/ship the wrong artifact, can leak a secret, can inject commands from untrusted input in CI.
- Medium: failure reported as success, or breaks on a supported platform.
- Low: breaks only on unusual filenames or environments not claimed as supported.

## Known false positives

- Unquoted expansions that are intentionally split (documented, e.g. `$FLAGS`) and cannot contain spaces or globs.
- `cmd || true` for best-effort cleanup whose failure is genuinely irrelevant.
- Missing `set -e` in scripts that check each step explicitly.
- ShellCheck warnings about `local x=$(cmd)` (SC2155) when the exit status is not used.
- BSD/GNU differences in scripts that are only ever run on one declared platform.
