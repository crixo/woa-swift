# GitHub Copilot and repository guidance

## Guidance files

- [`AGENTS.md`](../AGENTS.md) and
  [`.github/copilot-instructions.md`](../.github/copilot-instructions.md)
  contain repository-wide guidance.
- [`.github/instructions/`](../.github/instructions/) contains scoped
  instructions with `applyTo` patterns. They apply when relevant files are
  being worked on; they are not a replacement for the root instructions.
- [`.github/plans/`](../.github/plans/) stores approved feature and architecture
  plans. Review applicable plans before introducing significant behavior or
  architecture changes.
- [`.github/prompts/`](../.github/prompts/) contains feature prompts. A prompt
  is task-specific and does not replace the repository's always-on constraints.

## WOA compliance reviewer

The custom agent definition is
[`.github/agents/woa-compliance-reviewer.agent.md`](../.github/agents/woa-compliance-reviewer.agent.md).
Use it to review source changes for compliance with `AGENTS.md`,
`copilot-instructions.md`, and matching scoped instructions, especially after
SwiftUI feature work or before a release. It is a read-only reviewer; it does
not implement fixes.

For application navigation, sandbox/storage conventions, shared forms, and
change notifications, see the [architecture guide](architecture.md). For
builds and release operations, see [Build, release, and installation](build-and-release.md).