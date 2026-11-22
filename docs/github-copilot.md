# GitHub Copilot and repository guidance

## Guidance files

- [`AGENTS.md`](../AGENTS.md) and
  [`.github/copilot-instructions.md`](../.github/copilot-instructions.md)
  contain repository-wide development constraints.
- [`.github/instructions/`](../.github/instructions/) contains scoped
  instructions with `applyTo` patterns.
- [`.github/plans/`](../.github/plans/) stores approved feature and
  architecture plans. Review applicable plans before introducing significant
  behavior or architecture.
- [`.github/prompts/`](../.github/prompts/) contains task-specific prompts;
  prompts do not replace repository-wide rules.

## Review agents

The
[WOA compliance reviewer](../.github/agents/woa-compliance-reviewer.agent.md)
is read-only and reviews changes against repository and scoped instructions.
Other checked-in agents include general quality review, bug finding, and
implementation alternatives; see [`.github/agents/`](../.github/agents/).

For navigation, sandbox/storage conventions, shared forms, and change events,
see the [architecture guide](architecture.md). For build and release
operations, see [Build, release, and installation](build-and-release.md).
