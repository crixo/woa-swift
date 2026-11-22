# Bug Finder (core agent + Agent Skills)

A read-only defect-finding agent for GitHub Copilot custom agents, split into:

- `.github/agents/bug-finder.agent.md`: language-neutral core (role, safety, classification, validation, report format, final gate).
- `.github/skills/bug-finder-*/SKILL.md`: one Agent Skill per language or artifact type, holding the defect patterns, safe validation commands, severity notes, and known false positives.

At the start of a review the agent determines which file types are in scope, discovers the `bug-finder-*` skills, and loads every matching skill by name before reviewing those files (falling back to reading the `SKILL.md` directly if the skill mechanism is unavailable). The core rules always win; a skill can only add guidance. The final report lists which skills were loaded.

## Install

Unzip at the repository root so the paths are preserved:

```
<repo>/.github/agents/bug-finder.agent.md
<repo>/.github/bug-finder/README.md
<repo>/.github/bug-finder/SKILL.template.md
<repo>/.github/skills/bug-finder-*/SKILL.md
```

Select **Repository Bug Finder** in the agent picker. The agent writes its report to `quality-reports/latest/bugs.md`; it modifies no other file.

### Verify skill feature

Requirements: a Copilot client with Agent Skills support (VS Code agent mode, Copilot CLI, or the Copilot cloud agent). Depending on your VS Code version, Agent Skills may need to be enabled (the setting was `chat.useAgentSkills` while the feature was in preview). Check the current VS Code documentation.

There's no single version number to check against, because the docs describe it by feature. These checks are quick, from most to least direct:

1. **Type `/skills` in the Copilot Chat input.** This opens the Configure Skills menu. If it opens and lists your `bug-finder-*` skills, your version supports skills and has found the folders. If the command isn't recognized, your version is probably too old.
2. **Run "Chat: Open Customizations" from the Command Palette.** That opens the Agent Customizations editor, where you can discover, create and manage all your agent customizations in one place. Skills should appear there too.
3. **Search Settings for `chat.useAgentSkills`.** While the feature was experimental, you had to enable the "chat.useAgentSkills" setting to use Agent Skills. If the setting exists and is off, turn it on. If it doesn't exist, your version either predates skills or has made them the default, so use checks 1 and 2 to tell which.
4. **If neither works, update VS Code** (Help → Check for Updates) and check again. Early support landed in Insiders before stable, and GitHub's docs from that period say support in the stable version of VS Code was coming soon. I'd trust the live checks above over that older note.

Once skills show up, run the agent on a small folder and look at the "skills loaded" line in its report. It tells you whether the loading worked end to end, including the fallback of reading `SKILL.md` directly.

## Included skills

| Skill | Covers |
|---|---|
| `bug-finder-swift` | Swift, SwiftUI, concurrency, Package.swift, Xcode project settings, entitlements, privacy manifests |
| `bug-finder-shell` | bash/sh/zsh scripts, Makefiles, git hooks, build/release scripts |
| `bug-finder-ci-github-actions` | GitHub Actions workflows and composite actions, release pipelines |
| `bug-finder-tests` | test code, fixtures, mocks, test plans (any language) |
| `bug-finder-assets-localization` | asset catalogs, localization, plists/JSON/YAML/XML, SQL migrations |

Because these are standard Agent Skills, the same folders also work with other tools that read `.github/skills`, `.claude/skills`, or `.agents/skills`. Copy or symlink them if your tooling expects a different location.

## Add a language or artifact type

1. Create `.github/skills/bug-finder-<name>/SKILL.md` from `.github/bug-finder/SKILL.template.md` (the folder name must equal the skill `name`).
2. Write a narrow `description` that says which files the skill covers and that it is for reviewing them for defects, so it is not activated by unrelated tasks.
3. Fill in the "Activates on" section; the core agent matches it against the files in scope.
4. Nothing else changes. The core agent discovers `bug-finder-*` skills by directory.

Guidelines:

- Describe a concrete failure mechanism for each pattern, not just a suspicious construct.
- List only non-mutating, non-networked validation commands, each "only if already installed".
- Include a "Known false positives" section; it keeps the report short and credible.
- Never include instructions that relax the core safety rules; the core ignores them.
- Keep the template outside `.github/skills/` (as shipped) so it is not discovered as a skill.

## Troubleshooting

- A skill is not used: check that the folder name equals `name` in the frontmatter, the file is named exactly `SKILL.md`, and the final report's "skills loaded" list. The agent is instructed to load matching skills explicitly and to read the file directly if needed.
- Unrelated chats pick up bug-finder skills: narrow their `description`, or only enable the skills in repositories where you use this agent.

## Invocation prompts

The invocation defines what to review. Copy any block in full.

### Current branch / pull request (recommended default)

```text
Review the current branch and the code paths affected by its changes for confirmed and probable bugs.

Cover every changed artifact type: source code, scripts, tests, build and CI configuration, assets, and data files.

Follow dependencies, callers, callees, state flows, script invocations, resource consumers, and related tests beyond the changed files whenever necessary to validate behavior.

Pay particular attention to regressions introduced by the changes.

Do not report general maintainability issues or alternative implementations unless they directly cause a defect.
```

### Full repository

```text
Review the entire repository for confirmed and probable bugs.

Cover application code, scripts and automation, tests, build/CI/release configuration, assets and resources, and data/configuration files.

Focus on concrete correctness, concurrency, security, state-management, persistence, lifecycle, networking, file-system, error-handling, build, and release defects.

Validate suspected issues against call sites, related code, tests, repository instructions, and build/test results where safely possible.

Do not report general maintainability issues or alternative implementations unless they directly cause a defect.
```

### Specific directory

```text
Review Sources/Networking for confirmed and probable bugs.

Treat Sources/Networking as the primary review scope, but inspect callers, dependencies, models, configuration, scripts, and tests outside that directory whenever necessary to validate a suspected defect.

Do not expand the reporting scope to unrelated parts of the repository.
```

### Specific feature

```text
Review the authentication feature for confirmed and probable bugs.

Trace the feature across UI, state management, services, persistence, networking, configuration, scripts, CI, and tests as applicable.

Inspect code outside the feature when necessary to understand its execution paths, but report only defects relevant to the authentication feature.
```

### Specific files

```text
Review Sources/API/APIClient.swift and Sources/API/RequestBuilder.swift for confirmed and probable bugs.

Inspect their callers, dependencies, related models, configuration, and tests when necessary to determine whether a suspected issue is a real defect.

Keep reported findings focused on the specified files and behavior directly affected by them.
```

### Shell scripts and automation

```text
Review all shell scripts and automation under scripts/ and any scripts invoked by CI, Makefiles, or git hooks for confirmed and probable bugs.

Trace how each script is invoked, its arguments, environment, working directory, and exit-status handling.

Use non-executing checks (syntax checks and linters that are already installed); do not run the scripts.

Report only defects with a concrete failure path, including destructive-path, quoting, error-handling, portability (macOS vs Linux), and injection defects.
```

### Tests and test infrastructure

```text
Review the test suites, fixtures, mocks, and test plans for confirmed and probable bugs.

Look for tests that cannot fail, assert the wrong behavior, race on timing, depend on order or shared state, or are skipped or excluded in a way that hides defects in shipped code.

Verify that test targets and test plans actually include the tests that exist.

Do not report missing coverage as a bug unless it leaves a specific identified defect unprotected.
```

### Build, CI/CD, and release configuration

```text
Review the CI/CD workflows, package and project build settings, Info.plist, entitlements, privacy manifests, signing and packaging steps, and dependency manifests for confirmed and probable bugs.

Look for steps that do not run what they claim, failures that do not fail the job, secret exposure, script injection, version or deployment-target mismatches, and release paths that could ship an incorrect or unsigned artifact.

Do not report pinning or hardening preferences unless they violate repository policy or create a concrete risk.
```

### Assets, resources, and data files

```text
Review assets, localization files, bundled data files, schemas, and migrations for confirmed and probable bugs.

Verify that resources referenced by code exist, are included in the target, and match the format of the code that consumes them.

Check localization key and format-specifier consistency, asset catalog validity, and malformed or schema-invalid data files.
```

### Specific concern

```text
Review cancellation handling in the networking layer for confirmed and probable bugs.

Trace Task creation, ownership, cancellation propagation, async operations, continuations, callbacks, error handling, and relevant state transitions as necessary.

Report only defects related to cancellation behavior or behavior directly affected by it.
```

### Regression-focused review

```text
Review the current branch specifically for regressions introduced by its changes.

Compare changed behavior with surrounding implementation, established repository patterns, existing tests, and affected execution paths, across all artifact types.

Follow dependencies and call sites beyond the changed files whenever necessary to establish the regression.

Prioritize concrete behavioral changes that can cause incorrect runtime results.
```

### Minimal invocation

```text
Review the current branch for confirmed and probable bugs.
```
