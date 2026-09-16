# Github Copilot

## Custom Agents

### Woa compliance reviewer
`copilot-instructions.md`, `AGENTS.md`, and any matching `.instructions.md` files get injected into context no matter which chat mode you're in.
The custom agent adds a persona on top of it, with restricted tools and its own review-focused system prompt.

When to use it:
- Right after a feature prompt (.prompt.md) generates or edits views — before you accept the changes.
- Before you commit or open a PR, as your own stand-in for the code-review pass you don't have configured.
- After any hand-written edit you made yourself outside a prompt flow — that's exactly the kind of change that drifts from the rules unnoticed.
- Periodically on the whole src/ tree if you suspect drift has accumulated, e.g. right now, to see how much of the existing codebase already violates the new Navigation rule before you run the refactor prompt.

## Prompts

### refactor-responsive-swiftui
``` invocation
/refactor-responsive-swiftui Refactor the selected root view and only its directly related child views. Preserve the existing visual design and application behavior.
```