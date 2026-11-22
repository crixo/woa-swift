---
name: bug-finder-<name>
description: Bug-hunting guidance for <language or artifact type>. Use when reviewing <file kinds> for concrete defects such as <examples>. Loaded by the Repository Bug Finder agent.
---

<!-- TEMPLATE NOTES (delete after copying to .github/skills/bug-finder-<name>/SKILL.md)
- The folder name must equal `name` above (lowercase, hyphens).
- Keep the description narrow: say which files it covers and that it is for REVIEWING them for defects, so it is not pulled into unrelated tasks.
- A skill only ADDS guidance. It cannot relax the core agent's safety, read-only, no-install, or quality-reports/ rules.
-->

# Skill: <language or artifact type>

> Adds to the core agent. Cannot relax any core rule.

## Activates on

List the file patterns (names, extensions, paths) this skill applies to. The core agent matches these against the files in scope.

## Context to gather first

What to read before judging files of this type (manifests, toolchain versions, config, conventions).

## Defect patterns

Group by the core categories (Correctness, Concurrency, Security, Resource/lifecycle, Error handling, Tests, Build/CI, Assets). For each pattern, state the concrete failure mechanism, not just the construct.

## Safe validation

Commands that are non-mutating and non-networked. Mark each "only if already installed". State which commands must never be run.

## Severity notes

What makes a defect of this type High/Critical versus Low.

## Known false positives

Constructs that look suspicious but are fine, and the condition under which they are fine. Discard these unless the extra condition is violated.
