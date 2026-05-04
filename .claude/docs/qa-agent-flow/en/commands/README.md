# QA Slash Commands

This directory contains English slash command templates for the QA Agent Flow.

## Commands

| Command | File | Purpose |
| --- | --- | --- |
| `/qa-flow` | [qa-flow.md](./qa-flow.md) | Run the full QA flow end to end |
| `/qa-requirement` | [qa-requirement.md](./qa-requirement.md) | Analyze raw requirements |
| `/qa-strategy` | [qa-strategy.md](./qa-strategy.md) | Create layered test strategy |
| `/qa-bdd` | [qa-bdd.md](./qa-bdd.md) | Generate BDD scenarios and test case matrix |
| `/qa-automation-review` | [qa-automation-review.md](./qa-automation-review.md) | Design automation implementation and review quality |

## Relationship Between Agents And Commands

```text
Agent Markdown = the detailed job description and working standard
Command Markdown = a shortcut that invokes that role with user input
```

If your platform supports independent agents, put the `Direct-Use Agent Prompt` into the agent instruction and use commands only as optional shortcuts.

If your platform only supports commands, use these command files directly. Each one includes the role prompt and `{{user_input}}`.

## Placeholder

This template uses:

```text
{{user_input}}
```

Replace it according to your platform:

| Platform Type | Possible Placeholder |
| --- | --- |
| Generic | `{{user_input}}` |
| Cursor / Claude-style commands | `$ARGUMENTS` |
| Shell wrapper | stdin or `$1` |
| Custom agent platform | request input field |
